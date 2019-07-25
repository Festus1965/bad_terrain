-- Bad Terrain init.lua
-- Copyright Duane Robertson (duane@duanerobertson.com), 2017
-- Distributed under the LGPLv2.1 (https://www.gnu.org/licenses/old-licenses/lgpl-2.1.en.html)


bad_terrain = {}
mod = bad_terrain
mod_name = 'bad_terrain'
mod.version = "20171028"
mod.path = minetest.get_modpath(minetest.get_current_modname())
mod.world = minetest.get_worldpath()


local DEBUG


-- player surface damage and hunger
local dps_delay = 3

local last_dps_check = 0
local cold_delay = 5
local monster_delay = 3
local hunger_delay = 60
local dps_count = hunger_delay


local hot_stuff = {"group:surface_hot"}
local traps = {"group:trap"}
local trap_f = {}
local cold_stuff = {"group:surface_cold"}
local poison_stuff = {"group:poison"}
local hot_and_poison_stuff = {}
local gravity_off = {gravity = 0.1}
local gravity_on = {gravity = 1}
local sparking = {}
mod.hot_stuff = hot_stuff
mod.cold_stuff = cold_stuff
mod.poison_stuff = poison_stuff
mod.traps = traps
mod.trap_functions = trap_f

trap_f['slippery_floor_trap'] = function(tpos, player, player_name)
  if not (tpos and player and player_name) then
    return
  end

  player:set_physics_override({speed = 0.1})
  minetest.after(1, function() -- this effect is temporary
    player:set_physics_override({speed = 1})  -- we'll just set it to 1 and be done.
  end)
end

trap_f['fire_trap'] = function(tpos, player, player_name)
  if not (tpos and player and player_name) then
    return
  end

  minetest.set_node(tpos, {name="fire:basic_flame"})

  local hp = player:get_hp()
  if hp > 0 then
    player:set_hp(hp - 1)
  end
end

local function lightning_effects(pos, radius)
		if not (pos and radius) then
			return
		end

	minetest.add_particlespawner({
		amount = 30,
		time = 1,
		minpos = vector.subtract(pos, radius / 2),
		maxpos = vector.add(pos, radius / 2),
		minvel = {x=-10, y=-10, z=-10},
		maxvel = {x=10,  y=10,  z=10},
		minacc = vector.new(),
		maxacc = vector.new(),
		minexptime = 1,
		maxexptime = 3,
		minsize = 16,
		maxsize = 32,
		texture = "lightning.png",
	})
end

trap_f['electricity_trap'] = function(tpos, player, player_name)
  if not (tpos and player and player_name) then
    return
  end

  if not sparking[player_name] then
    sparking[player_name] = true
    local hp = player:get_hp()
    if hp > 0 then
      player:set_hp(hp - 1)
      lightning_effects(tpos, 3)
      minetest.sound_play("default_dig_crumbly", {pos = tpos, gain = 0.5, max_hear_distance = 10})
    end

    minetest.after(1, function()
      sparking[player_name] = nil
    end)
  end
end

trap_f['ice_trap'] = function(tpos, player, player_name)
  if not (tpos and player and player_name) then
    return
  end

	local ppos = player:getpos()
	if ppos then
		ppos.y = ppos.y + 1
		local p1 = vector.subtract(ppos, 2)
		local p2 = vector.add(ppos, 2)
		local nodes = minetest.find_nodes_in_area(p1, p2, 'air')
		if not (nodes and type(nodes) == 'table') then
			return
		end

		for _, npos in pairs(nodes) do
			minetest.set_node(npos, {name="default:ice"})
		end

		minetest.set_node(tpos, {name="default:ice"})
	end
end

trap_f['lava_trap'] = function(tpos, player, player_name)
  if not (tpos and player and player_name) then
    return
  end

	minetest.set_node(tpos, {name="default:lava_source"})
	minetest.sound_play("default_dig_crumbly", {pos = tpos, gain = 0.5, max_hear_distance = 10})
	local hp = player:get_hp()
	if hp > 0 then
		player:set_hp(hp - 2)
	end
end

if minetest.registered_nodes['tnt:tnt_burning'] then
	-- 5... 4... 3... 2... 1...
  trap_f['explosive_trap'] = function(tpos, player, player_name)
    if not (tpos and player and player_name) then
      return
    end

		minetest.set_node(tpos, {name="tnt:tnt_burning"})
		local timer = minetest.get_node_timer(tpos)
		if timer then
			timer:start(5)
		end
		minetest.sound_play("default_dig_crumbly", {pos = tpos, gain = 0.5, max_hear_distance = 10})
	end
else
	-- wimpier trap for non-tnt settings
  trap_f['explosive_trap'] = trap_f['lava_trap']
end


if not minetest.add_group then
  -- Modify a node to add a group
  function minetest.add_group(node, groups)
    local def = minetest.registered_items[node]
    if not (node and def and groups and type(groups) == 'table') then
      return false
    end
    local def_groups = def.groups or {}
    for group, value in pairs(groups) do
      if value ~= 0 then
        def_groups[group] = value
      else
        def_groups[group] = nil
      end
    end
    minetest.override_item(node, {groups = def_groups})
    return true
  end
end


minetest.add_group('default:snow', {surface_cold = 1})
minetest.add_group('default:dirt_with_snow', {surface_cold = 1})
minetest.add_group('default:ice', {surface_cold = 1})


local warmth
if minetest.get_modpath('dinv') then
	warmth = dinv.get_warmth
else
	warmth = function(player)
		return 0
	end
end


minetest.register_globalstep(function(dtime)
	if not (dtime and type(dtime) == 'number') then
		return
	end

	local time = minetest.get_gametime()
	if not (time and type(time) == 'number') then
		return
	end

	-- Trap check
	if last_dps_check and time - last_dps_check < 1 then
		return
	end

	local minetest_find_nodes_in_area = minetest.find_nodes_in_area
	local players = minetest.get_connected_players()
	if not (players and type(players) == 'table') then
		return
	end

	if #hot_and_poison_stuff ~= #hot_stuff + #poison_stuff then
		hot_and_poison_stuff = table.copy(hot_stuff)
		for _, i in pairs(poison_stuff) do
			hot_and_poison_stuff[#hot_and_poison_stuff+1] = i
		end
	end

	for i = 1, #players do
		local player = players[i]
		local pos = player:getpos()
		pos = vector.round(pos)
		local player_name = player:get_player_name()

		local minp = vector.subtract(pos, 2)
		local maxp = vector.add(pos, 2)
		local counts = minetest_find_nodes_in_area(minp, maxp, traps)
		if counts and type(counts) == 'table' and #counts > 0 then
			for _, tpos in ipairs(counts) do
        for non_loop = 1, 1 do
          local node = minetest.get_node_or_nil(tpos)
          if not (node and node.name and minetest.registered_nodes[node.name] and minetest.registered_nodes[node.name].groups) then
            break
          end
          for g, v in pairs(minetest.registered_nodes[node.name].groups) do
            if type(trap_f[g]) == 'function' then
              trap_f[g](tpos, player, player_name)
            --else
              --minetest.remove_node(tpos)
            end
          end
        end
			end
		end

		-- Execute only after an interval.
		if last_dps_check and time - last_dps_check >= dps_delay then
			-- environmental damage
			if DEBUG and player:get_hp() < 20 then
				-- Regenerate the player while testing.
				print("HP: "..player:get_hp())
				player:set_hp(20)
				return
			else
				local minp = vector.subtract(pos, 1)
				local maxp = vector.add(pos, 1)

				-- ... from standing on or near hot/poison objects.
				local counts =  minetest_find_nodes_in_area(minp, maxp, hot_and_poison_stuff)
				if not (counts and type(counts) == 'table') then
					return
				end

				if #counts > 1 then
					player:set_hp(player:get_hp() - 1)
					minetest.chat_send_player(player_name, "This stuff is hot!")
				end

				-- ... from standing on or near cold objects (less often).
				if dps_count % cold_delay == 0 then
					counts =  minetest_find_nodes_in_area(minp, maxp, cold_stuff)
					if not (counts and type(counts) == 'table') then
						return
					end

					if #counts > 1 and warmth(player) < 1 then
						player:set_hp(player:get_hp() - 1)
						minetest.chat_send_player(player_name, "You're freezing.")
					end
				end

				-- ... from hunger (even less often).
				if dps_count % hunger_delay == 0 and mod.hunger_change then
					mod.hunger_change(player, -1)
				end
			end
		end
	end

	-- Execute only after an interval.
	if last_dps_check and time - last_dps_check < dps_delay then
		return
	end

	--local out = io.open(mod.world..'/bad_terrain_data.txt','w')	
	--if out then
	--	out:write(minetest.serialize(mod.db))
	--	out:close()
	--end

	-- Set this outside of the player loop, to affect everyone.
	if dps_count % hunger_delay == 0 then
		dps_count = hunger_delay
	end

	last_dps_check = minetest.get_gametime()
	if not (last_dps_check and type(last_dps_check) == 'number') then
		last_dps_check = 0
	end
	dps_count = dps_count - 1
end)
