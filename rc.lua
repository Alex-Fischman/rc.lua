local gears =     require("gears")
local awful =     require("awful")
                  require("awful.autofocus")
local wibox =     require("wibox")
local beautiful = require("beautiful")
local naughty =   require("naughty")
local hotkeys =   require("awful.hotkeys_popup")

naughty.config.defaults.timeout = 15
if awesome.startup_errors then
	naughty.notify({text = awesome.startup_errors})
end

local in_error = false
awesome.connect_signal("debug::error", function (err)
	if in_error then return end
	
	in_error = true
	naughty.notify({text = tostring(err)})
	in_error = false
end)

local theme = "default/theme.lua"
local terminal = "alacritty -o font.size=6.5"
local editor = "subl"
local bar_height = 24

awful.spawn("xinput set-prop \"Logitech USB Trackball\" \"libinput Scroll Method Enabled\" 0, 0, 1")
awful.spawn("xinput set-prop \"PIXA3854:00 093A:0274 Touchpad\" \"libinput Disable While Typing Enabled\" 0")
local laptopScreen =  "xrandr --output eDP-1  --auto --primary; xrandr --output DP-2-1 --off"
local desktopScreen = "xrandr --output DP-2-1 --auto --primary; xrandr --output eDP-1  --off"

beautiful.init(gears.filesystem.get_themes_dir() .. theme)
beautiful.font = "sans 10"
beautiful.master_width_factor = 1 / 3

local main_layout = {name = "fairh"}
function main_layout.arrange(p)
	if #p.clients == 0 then return end

	local t = p.tag or screen[p.screen].selected_tag
	local masterNumber = math.min(math.max(t.master_count, 1), #p.clients)
	local slavesWidth = p.workarea.width * (1 - t.master_width_factor) / 2
	local leftSlavesHeight  = p.workarea.height / math.ceil((#p.clients - masterNumber) / 2)
	local rightSlavesHeight = p.workarea.height / math.floor((#p.clients - masterNumber) / 2)

	for i = 1, #p.clients do
		if i <= masterNumber then
			p.geometries[p.clients[i]] = {
				x = p.workarea.x + slavesWidth,
				y = p.workarea.y + p.workarea.height / masterNumber * (i - 1),
				width = p.workarea.width * t.master_width_factor,
				height = p.workarea.height / masterNumber
			}

			if t.master_fill_policy == "expand" then
				if masterNumber == #p.clients then
					p.geometries[p.clients[i]].x = p.workarea.x
					p.geometries[p.clients[i]].width = p.workarea.width
				elseif #p.clients - masterNumber == 1 then
					p.geometries[p.clients[i]].width = p.workarea.width - slavesWidth
				end
			end
		elseif (i - masterNumber - 1) % 2 == 0 then
			p.geometries[p.clients[i]] = {
				x = p.workarea.x,
				y = p.workarea.y + leftSlavesHeight * (i - masterNumber - 1) / 2,
				width = slavesWidth,
				height = leftSlavesHeight
			}
		else
			p.geometries[p.clients[i]] = {
				x = p.workarea.x + slavesWidth + p.workarea.width * t.master_width_factor,
				y = p.workarea.y + rightSlavesHeight * (i - masterNumber - 2) / 2,
				width = slavesWidth,
				height = rightSlavesHeight
			}
		end
	end
end

function main_layout.mouse_resize_handler(c, corner, x, y)
	local t  = c.screen.selected_tag
	local wa = c.screen.workarea
	
	mouse.coords({ x = wa.x + wa.width * (1 - t.master_width_factor) / 2 })

	mousegrabber.run(function(mouse)
		t.master_width_factor = 1 - (mouse.x - wa.x) / wa.width * 2
		return mouse.buttons[3]
	end, "sb_h_double_arrow")
end

local game_layout = {name = "magnifier"}
function game_layout.arrange(p)
	if #p.clients == 0 then return end
	local width = 1920
	local height = 1080
	p.geometries[p.clients[1]] = {
		x = p.workarea.x + p.workarea.width / 2 - width / 2,
		y = p.workarea.y,
		width = width,
		height = height,
	}
	if #p.clients == 1 then return end
	p.geometries[p.clients[2]] = {
		x = p.workarea.x + p.workarea.width / 2 - width / 2,
		y = p.workarea.y + height,
		width = width,
		height = p.workarea.height - height
	}
	if #p.clients == 2 then return end
	p.geometries[p.clients[3]] = {
		x = p.workarea.x,
		y = p.workarea.y,
		width = (p.workarea.width - width) / 2,
		height = p.workarea.height,
	}
	if #p.clients == 3 then return end
	p.geometries[p.clients[4]] = {
		x = p.workarea.x + p.workarea.width / 2 + width / 2,
		y = p.workarea.y,
		width = (p.workarea.width - width) / 2,
		height = p.workarea.height,
	}
end

awful.layout.layouts = {
	main_layout,
	game_layout,
	awful.layout.suit.floating,
	awful.layout.suit.spiral.dwindle
}

local function set_wallpaper(s)
	gears.wallpaper.maximized(beautiful.wallpaper, s, true)
end

screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)
	set_wallpaper(s)
	
	awful.tag({"1", "2", "3", "4", "5", "6"}, s, awful.layout.layouts[1])
	
	s.mypromptbox = awful.widget.prompt()
	s.mylayoutbox = awful.widget.layoutbox(s)
	s.mylayoutbox:buttons(gears.table.join(
		awful.button({}, 1, function () awful.layout.inc(1) end),
		awful.button({}, 3, function () awful.layout.inc(-1) end),
		awful.button({}, 4, function () awful.layout.inc(1) end),
		awful.button({}, 5, function () awful.layout.inc(-1) end)
	))
	s.mytaglist = awful.widget.taglist {
		screen = s,
		filter = awful.widget.taglist.filter.all,
		buttons = gears.table.join(
			awful.button({}, 1, function(t) t:view_only() end),
			awful.button({}, 4, function(t) awful.tag.viewnext(t.screen) end),
			awful.button({}, 5, function(t) awful.tag.viewprev(t.screen) end),
			awful.button({"Mod4"}, 1, function(t) client.focus:move_to_tag(t) end)
		)
	}
	s.battery = wibox.widget.textbox()
	gears.timer {
	    timeout = 20,
	    autostart = true,
	    call_now = true,
	    callback = function()
	        awful.spawn.easy_async_with_shell("cat /sys/class/power_supply/BAT*/uevent", function(out)
	            local capacity = string.match(out, "POWER_SUPPLY_CAPACITY=(%d*)")
	            local status = string.match(out, "POWER_SUPPLY_STATUS=(.-)\n")
	            s.battery:set_text(status .. ": " .. capacity .. "%")
	        end)
	    end
	}
	s.mytasklist = awful.widget.tasklist {
		screen = s,
		filter = awful.widget.tasklist.filter.currenttags,
		buttons = gears.table.join(
			awful.button({}, 1, function (c) client.focus = c c:raise() end),
			awful.button({}, 3, function () awful.menu.client_list() end),
			awful.button({}, 4, function () awful.client.focus.byidx(1) end),
			awful.button({}, 5, function () awful.client.focus.byidx(-1) end)
		)
	}
	s.mywibox = awful.wibar({position = "top", screen = s, height = bar_height})
	s.mywibox:setup {
		layout = wibox.layout.align.horizontal,
		{
			layout = wibox.layout.fixed.horizontal,
			spacing = 5,
			awful.widget.launcher({
				image = beautiful.awesome_icon,
				menu = awful.menu({
					{"Hotkeys", function() hotkeys.show_help() end},
					{"Awesome", editor .. " " .. awesome.conffile},
					{"NixOS", editor .. " " .. "/etc/nixos/configuration.nix"},
					{"Terminal", terminal},
					{"Restart", awesome.restart},
					{"Quit", function() awesome.quit() end},
				})
			}),
			s.mylayoutbox,
			wibox.widget.textclock("%a, %b %d %I:%M"),
			s.mytaglist,
			wibox.widget.systray(),
			s.mypromptbox,
		},
		s.mytasklist,
		{
			layout = wibox.layout.fixed.horizontal,
			wibox.container.margin(s.battery, 5, 5)
		}
	}
end)

local globalkeys = gears.table.join(
	awful.key({"Mod4"}, "k", hotkeys.show_help,
		{description = "show hotkeys", group = "awesome"}),
	awful.key({"Mod4", "Control"}, "r", awesome.restart,
		{description = "reload awesome", group = "awesome"}),
	awful.key({"Mod4", "Control"}, "q", awesome.quit,
		{description = "quit awesome", group = "awesome"}),

	awful.key({"Mod1"}, "Tab", function () awful.client.focus.byidx(-1) end,
		{description = "focus next client by index", group = "client"}),
	awful.key({"Mod1", "Shift"}, "Tab", function () awful.client.focus.byidx(1) end,
		{description = "focus prev client by index", group = "client"}),
	awful.key({"Mod1", "Mod4"}, "Tab", function () awful.client.swap.byidx(-1) end,
		{description = "swap with next client by index", group = "client"}),
	awful.key({"Mod1", "Mod4", "Shift"}, "Tab", function () awful.client.swap.byidx(1) end,
		{description = "swap with prev client by index", group = "client"}),
	
	awful.key({"Mod4"}, "u", awful.client.urgent.jumpto,
		{description = "jump to urgent client", group = "client"}),
	awful.key({"Mod4", "Control"}, "n", function ()
			awful.client.restore():emit_signal("request::activate", "key.unminimize")
		end,
		{description = "restore minimized", group = "client"}),

	awful.key({"Mod4"}, "Left", awful.tag.viewprev,
		{description = "view prev tag", group = "tag"}),
	awful.key({"Mod4"}, "Right", awful.tag.viewnext,
		{description = "view next tag", group = "tag"}),

	awful.key({"Mod4"}, "1", function () root.tags()[1]:view_only() end,
		{description = "view tag 1", group = "tag"}),
	awful.key({"Mod4"}, "2", function () root.tags()[2]:view_only() end,
		{description = "view tag 2", group = "tag"}),
	awful.key({"Mod4"}, "3", function () root.tags()[3]:view_only() end,
		{description = "view tag 3", group = "tag"}),
	awful.key({"Mod4"}, "4", function () root.tags()[4]:view_only() end,
		{description = "view tag 4", group = "tag"}),
	awful.key({"Mod4"}, "5", function () root.tags()[5]:view_only() end,
		{description = "view tag 5", group = "tag"}),
	awful.key({"Mod4"}, "6", function () root.tags()[6]:view_only() end,
		{description = "view tag 6", group = "tag"}),
	
	awful.key({"Mod4"}, "Return", function () awful.spawn(terminal) end,
		{description = "open a terminal", group = "launcher"}),
	awful.key({"Mod4"}, "r", function () awful.screen.focused().mypromptbox:run() end,
		{description = "run prompt", group = "launcher"}),
	awful.key({"Mod4"}, "l", function () awful.spawn.with_shell("xsecurelock") end,
		{description = "start screensaver", group = "launcher"}),
	
	awful.key({"Mod4"}, "x", function () awful.tag.incnmaster(1) end,
		{description = "increase master client number", group = "layout"}),
	awful.key({"Mod4", "Control"}, "x", function () awful.tag.incnmaster(-1) end,
		{description = "decrease master client number", group = "layout"}),
	awful.key({"Mod4"}, "z", function () awful.tag.incncol(1) end,
		{description = "increase the number of columns", group = "layout"}),
	awful.key({"Mod4", "Control"}, "z", function () awful.tag.incncol(-1) end,
		{description = "decrease the number of columns", group = "layout"}),
	awful.key({"Mod4"}, "space", function () awful.layout.inc(1) end,
		{description = "select next layout", group = "layout"}),
	awful.key({"Mod4", "Control"}, "space", function () awful.layout.inc(-1) end,
		{description = "select prev layout", group = "layout"}),

	awful.key({"Mod4", "Control"}, "1", function () awful.spawn.with_shell(laptopScreen) end,
		{description = "switch to laptop screen", group = "layout"}),
	awful.key({"Mod4", "Control"}, "2", function () awful.spawn.with_shell(desktopScreen) end,
		{description = "switch to desktop screen", group = "layout"})
)

local clientkeys = gears.table.join(
	awful.key({"Mod4"}, "f", function (c) c.fullscreen = not c.fullscreen end,
		{description = "toggle fullscreen", group = "client"}),
	awful.key({"Mod4", "Control"}, "c", function (c) c:kill() end,
		{description = "close", group = "client"}),
	awful.key({"Mod4", "Control"}, "Return", function (c) c:swap(client.getmaster()) end,
		{description = "move to master", group = "client"}),
	awful.key({"Mod4"}, "t", function (c) c.ontop = not c.ontop end,
		{description = "toggle keep on top", group = "client"}),
	awful.key({"Mod4"}, "n", function (c) c.minimized = true end,
		{description = "minimize", group = "client"}),
	awful.key({"Mod4"}, "m", function (c) c.maximized = not c.maximized end,
		{description = "maximize", group = "client"}),
	
	awful.key({"Mod4", "Control"}, "3", function (c) c.screen.selected_tag.master_width_factor = 1 / 3 end,
		{description = "thirds", group = "layout"}),

	awful.key({"Mod4", "Control"}, "Left", function (c)
			c:move_to_tag(root.tags()[(c.first_tag.index-2)%tag:instances()+1])
			awful.tag.viewprev()
		end,
		{description = "move to prev tag", group = "tag"}),
	awful.key({"Mod4", "Control"}, "Right", function (c)
			c:move_to_tag(root.tags()[c.first_tag.index%tag:instances()+1])
			awful.tag.viewnext()
		end,
		{description = "move to next tag", group = "tag"})
)

root.keys(globalkeys)

client.connect_signal("request::titlebars", function(c)
	local buttons = gears.table.join(
		awful.button({}, 1, function() awful.mouse.client.move(c) end),
		awful.button({}, 3, function() awful.mouse.client.resize(c) end)
	)
		
	awful.titlebar(c, {size = bar_height}) : setup {
		layout = wibox.layout.align.horizontal,
		{
			layout = wibox.layout.fixed.horizontal,
			buttons = buttons,
			awful.titlebar.widget.iconwidget(c),
		},
		{
			layout = wibox.layout.flex.horizontal,
			buttons = buttons,
			{
				align = "center",
				widget = awful.titlebar.widget.titlewidget(c)
			},
		},
		{
			layout = wibox.layout.fixed.horizontal,
			awful.titlebar.widget.floatingbutton(c),
			awful.titlebar.widget.maximizedbutton(c),
			awful.titlebar.widget.stickybutton(c),
			awful.titlebar.widget.ontopbutton(c),
			awful.titlebar.widget.closebutton(c),
		},
	}
end)

client.connect_signal("mouse::enter", 
	function(c) c:emit_signal("request::activate", "mouse_enter") end)
client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
client.connect_signal("manage", function (c) awful.client.setslave(c) end)

awful.rules.rules = {
	{
		rule = {},
		properties = {
			border_width = beautiful.border_width,
			border_color = beautiful.border_normal,
			focus = awful.client.focus.filter,
			raise = true,
			keys = clientkeys,
			screen = awful.screen.preferred,
			placement = awful.placement.no_overlap + awful.placement.no_offscreen
		}
	},
	{
		rule_any = {role = {"pop-up"}},
		properties = {floating = true}
	},
	{
		rule_any = {type = {"normal", "dialog"}},
		properties = {titlebars_enabled = true}
	},
}
