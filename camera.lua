-- Base Functions

function _init()
  _update = opening_update
  _draw = opening_draw
end

function enter_dungeon()
  init_player()
  generate_level()
  _update = dungeon_update
  _draw = dungeon_draw
end


-- Opening Screen
function opening_draw()
  cls()
  print("camera dungeon", 34, 64, 9)
  print("press x to start", 30, 74, 9)
end

function opening_update()
  if (btnp(❎) or btnp(🅾️)) enter_dungeon()
end

-- Drawing Functions

function dungeon_draw()
 cls()
 draw_dungeonmap()
 draw_entities()
 fog_shader()
end

function draw_dungeonmap()
	mapcamx = mid(-1, player.x-8, mapx-14)
	mapcamy = mid(-1, player.y-8, mapy-14)
	map(mapcamx, mapcamy, 0, 0, mapx, mapy)
end

function fog_shader()
	for i = 0,15 do
		for j = 0,15 do
			fillp(fogofwar[xy2i(mapcamx+i,mapcamy+j)])
			rectfill(i*8,j*8,i*8+7,j*8+7,0)
		end
	end
end

function draw_entities()
	for e in all(ents) do
		spr(e.spr, (e.x-mapcamx)*8, (e.y-mapcamy)*8)
	end
end

-- Utility Functions

function rndint(a,b)
	return flr(rnd()*(b-a)+0.5)+a
end

function xy2i(x,y)
  if (x < 0 or x > mapx) return -1
  if (y < 0 or y > mapy) return -1
	return x+y*mapx
end

-- Level Generation

mapx = 20
mapy = 20

function generate_level(N)
	ents = {}
	entmap = {}
  fogofwar = {}

	add(ents, player)

	for i = 0,mapx do
		for j = 0,mapy do
			mset(i,j,1)
			fogofwar[xy2i(i,j)] = 0
		end
	end

  -- creating maze
	recurse(0,0,mapx,mapy)
	clearwalls()

  -- spawning objects
	add_anyempty(make_upstairs)
	add_anyempty(make_downstairs)

  -- Spawning Creatures
	add_anyempty(make_slime)
	add_anyempty(make_slime)
	add_anyempty(make_slime)
end

function add_anyempty(makefun)
	done = false
	while not done do
		local x = rndint(1,mapx)
		local y = rndint(1,mapy)
		local te = entmap_get(x,y)
		if mget(x,y) == 4 and #te == 0 then
			makefun(x,y)
			done = true
		end
	end
end

function clearwalls()
	for i = 0,mapx do
		for j = 0,mapy do
			if mget(i,j) == 1 then
				local rem = true
				for ii = i-1, i+1 do
					for jj = j-1, j+1 do
						rem = rem and mget(ii,jj) != 4
					end
				end
				if (rem) mset(i,j,0)
			end
		end
	end
end

function recurse(sw,sh,ew,eh)
	if (ew - sw < 13 or eh - sh < 13) do
	 return makeroom(sw,sh,ew,eh)
	else
		-- recurse time
		local p1,p2 = 0,0
		if (ew - sw > eh - sh) then
			local mpt = flr((sw+ew)/2)
			local cut = rndint(mpt-3,mpt+3)
			p2 = recurse(cut,sh,ew,eh)
			p1 = recurse(sw,sh,cut,eh)
		else
			local mpt = flr((sh+eh)/2)
			local cut = rndint(mpt-3,mpt+3)
			p1 = recurse(sw,sh,ew,cut)
			p2 = recurse(sw,cut,ew,eh)
		end
		-- corridor
		makecorridor(p1[1],p1[2],p2[1],p2[2])
		return (rnd() > 0.5 and p1 or p2)
	end
end

function makeroom(sw,sh,ew,eh)
	local rw = max(rndint(1,ew-sw-2),rndint(1,ew-sw-2))
	local rh = max(rndint(1,eh-sh-2),rndint(1,eh-sh-2))
	local rsw = rndint(sw+1, ew-rw-1)
	local rsh = rndint(sh+1, eh-rh-1)

	for i = rsw, rsw+rw do
		for j = rsh, rsh+rh do
		 mset(i,j,4)
		end
	end
	return { rndint(rsw,rsw+rw),
										rndint(rsh,rsh+rh) }
end

function makecorridor(sw,sh,ew,eh)
	for i = sw,ew,sgn(ew-sw) do
		mset(i,sh,4)
	end
	for i = sh,eh,sgn(eh-sh) do
		mset(ew,i,4)
	end
end

-- Make Objects
function make_upstairs(x,y)
	local us = {spr = 3, x = x, y = y}
  us.collide = upstairs_collide
	add(ents,us)
	ent_setpos(us,us.x,us.y)

	-- put the player near the upstairs
	for i=us.x-1,us.x+1 do
		for j=us.y-1,us.y+1 do
			local te = entmap_get(i,j)
			if mget(i,j) == 4 and #te == 0 then
				ent_setpos(player,i,j)
				return
			end
		end
	end
end

function make_downstairs(x,y)
	local us = {spr = 2, x = x, y = y}
  us.collide = downstairs_collide

	add(ents,us)
	ent_setpos(us,us.x,us.y)
end

function downstairs_collide(self, e)
  if (e != player) return false
  generate_level()
  return true
end

function upstairs_collide(self, e)
  _init()
  return true
end


-- entities

function entmap_get(x,y)
	local i = xy2i(x,y)
	if (entmap[i] == nil) entmap[i] = {}
	return entmap[i]
end

function entmap_put(x,y,el)
	entmap[xy2i(x,y)] = el
end

function move_ent(x,y,e)
	-- check for map collision
	if fget(mget(x,y),0) then
		if (e == player) sfx(0)
		return
	end

	-- check for entity collision
	local te = entmap_get(x,y)
	for ent in all(te) do
		if ent.collide then
			local end_turn = ent.collide(ent,e)
			if (end_turn) return
		end
	end

	-- do the move
	ent_setpos(e,x,y)
end

function do_turn()
	for e in all(ents) do
		if e.act then
			--	printh(e.act)
			e.act += e.speed
			while e.act >= 1 do
				e.turn(e)
				e.act -= 1
			end
		end
	end
end

function ent_setpos(e,x,y)
	local tfrom = entmap_get(e.x, e.y)
	local tto = entmap_get(x,y)

	e.x = x
	e.y = y

	del(tfrom,e)
	add(tto,e)

	if (e == player) defog(x,y)
end



function init_player()
	player = {spr = 16, x = 0, y = 0}
end

function make_slime(x,y)
	local slime = {
		spr = 17,
		x = x, y = y,
		speed = 0.5, act = 0,
		turn = slime_turn,
		collide = slime_collide
	}
	add(ents, slime)
	ent_setpos(slime, slime.x, slime.y)
end

function slime_turn(e)
	local dx = 0
	local dy = 0
	local ox = e.x
	local oy = e.y

	if e.pushed == true then
		dx = e.dx
		dy = e.dy
	else
		repeat
			dx = flr(rnd(3))-1
			dy = flr(rnd(3))-1
		until (dx*dy != 0)
	end

	move_ent(e.x+dx, e.y+dy, e)
	if (e.x == ox and e.y == oy) e.pushed = false e.speed = 0.5
end

function slime_collide(s,e)
	s.dx = s.x - e.x
	s.dy = s.y - e.y
	s.pushed = true
	s.speed = 1
end

-- Interface


function dungeon_update()
  input_move()
end

function input_move()
	if (btnp(➡️)) move_ent(player.x+1, player.y, player) do_turn()
	if (btnp(⬅️)) move_ent(player.x-1, player.y, player) do_turn()
	if (btnp(⬆️)) move_ent(player.x, player.y-1, player) do_turn()
	if (btnp(⬇️)) move_ent(player.x, player.y+1, player) do_turn()
end

function defog(x,y)
	for i = 0,#fogofwar do
		if (fogofwar[i] < 0) fogofwar[i] = ▒
	end
	--fogofwar[xy2i(x,y)] = 1
	for a = 0,31 do
		for d = 0,5 do
			local vx = x + flr(cos(a/32)*d+0.5)
			local vy = y + flr(sin(a/32)*d+0.5)
			fogofwar[xy2i(vx,vy)] = 0b1111111111111111.100
			if (fget(mget(vx,vy),0)) break
		end
	end
end
