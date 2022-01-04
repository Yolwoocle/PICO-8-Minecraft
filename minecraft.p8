pico-8 cartridge // http://www.pico-8.com
version 34
__lua__
--minecaft on pico-8
--by yolwoocle 
function _init()
	fps=60
	--flags
	breakable=0
	transparent=6
	solid=7
	
	poke(0x5f2d,1)
	mx,my=stat(32),stat(33)
	camx,camy=0,0
	ox,oy=0,0
	ww=128
	wh=64
	--srand(stat(0)+stat(1)+stat(2))
	seed=rnd(-1)--we might get negative values, but that's okay
	
	particles={}
	grassh={}
	
	cu=make_cu()
	gen_world()
	
	actors={}
	init_actors()
	
	make_craft_menu()
	furnaces={}
	
	create_background()
end

function init_actors()
	actors = {
		[1]=make_player(64,64,64),
		[10]=make_cu(),
	}
	player = actors[1]
	--define player cursor
	player.cu = actors[10]
end

function prints(text,x,y)
	print(text,x,y+1,1)
	if text=="⬆️"or text=="⬇️"
	or text=="🅾️"then
		print("●",x+1,y+1,1)
	end
	print(text,x,y,  7)
end

function make_ptc(pos,spd,s,col,fric,g)
	return {
		x=pos[1],
		y=pos[2],
		dx=spd[1],
		dy=spd[2],
		fric=fric,
		g=g,
		
		s=s,
		ds=ds,
		
		col=col,
		
		destroy=false,
	}
end

function mine_ptc(x,y,col)
	return make_ptc(
	{x+rnd(8),y+rnd(8)},
	{rnd(2)-1, -rnd(2)},
	rnd(2)+1, col, 0.95,0.3)
end

function update_ptc(p)
	p.dx *= p.fric
	p.dy += p.g
	p.dy *= p.fric
	
	p.x += p.dx
	p.y += p.dy
	
	p.s *= p.fric
	
	if p.s<0.5 then
		p.destroy=true
	end
end

function draw_ptc(p)
	rectfill(p.x-p.s, p.y-p.s,
	         p.x+p.s, p.y+p.s, 
	         p.col)
end


function darkpal()
	pal()
	for i=0,15 do
		pal(i,sget(1+(i\8)*4,i%8))
	end
end


function waterpal()
	pal()
	for i=0,15 do
		pal(i,sget(3+(i\8)*4,i%8))
	end
end

function lightpal()
	pal()
	for i=0,15 do
		pal(i,sget(2+(i\8),i%8))
	end
end

-->8
--update
function _update60()--fps=60
	mx,my=stat(32),stat(33)
	mlc=stat(34)&1!=0
	mrc=stat(34)&2!=0
	mmc=stat(34)&4!=0
	mscrl=stat(36)
	
	for k,v in pairs(actors)do
		v:update()
	end
	
	for p in all(particles) do
		update_ptc(p)
		if p.destroy then
			del(particles,p)
		end
	end
	
	if craft_active then
		update_craft_menu(player)
	end
	
	if(btn(⬅️))ox-=1
	if(btn(➡️))ox+=1
	if(btn(⬆️))oy-=1
	if(btn(⬇️))oy+=1
	
	camera(camx+ox,camy+oy)
end 
-->8
--draw
function _draw()
	cls(12)
	
	draw_background()
	
	draw_world()
	for p in all(particles) do
		draw_ptc(p)
	end
	
	palt(12,false)
	palt(0,true)
	for k,v in pairs(actors) do
		v:draw()
	end
	
	if craft_active then
		draw_craft_menu(camx+64,camy+64)
	end
	
	--furnaces
	for i,f in pairs(furnaces)do
		pos=id2pos(i)
		print(f.prog,pos.x*8,pos.y*8)
	end
	
	--debug
	function coll(c)
		local t={
			[0]=13,
			[3]=4,
			[4]=11,
			[5]=4,
			[6]=3,
			[9]=6,
			[29]=13,
			[30]=5,
			[48]=0,
			[49]=15,
			[50]=10,
			[51]=12,
			[52]=8,
		}
		return t[c]
	end
	for y=0,63 do
		for x=0,127 do
			--pset(camx+x,camy+y+64,coll(mget(x,y)))
		end
	end
	
	palt()
	
	color(7)
	local p = actors[1]
	
	--print("unfinished demo",camx+35,camy+120)
	
	--print(time(),camx+10,camy+60,1)
end

-->8
--collision
--FIXME: collisions suck

function is_solid(x,y, a)
	if a!=nil and a[1]==x\8 and
	a[2]==y\8 then
		return true
	end
	if(x<0 or 128*8<=x) return true
	
	return fget(mget(x\8,y\8),solid)
end

function rectcoll(x,y,w,h, a)
	--a:additional block
	return is_solid(x,   y,  a)or 
	       is_solid(x+w, y,  a)or 
	       is_solid(x,   y+h,a)or
	       is_solid(x+w, y+h,a)
end

function collide(p)
	local x,y = p.x,p.y
	local dx,dy = p.dx,p.dy
	local w,h = p.bw,p.bh
	local ox,oy = x+p.bx,y+p.by
	
	--collisions
	local coll_x = rectcoll( 
	ox+dx, oy,    w, h)
	local coll_y = rectcoll(
	ox,    oy+dy, w, h)
	local coll_xy = rectcoll(
	ox+dx, oy+dy, w, h)
	
	if coll_x then
		p.dx *= -p.bounce
	end
	
	p.grounded = false
	if coll_y then
		if(dy > 0) p.grounded = true
		p.dy *= -p.bounce
	end
	
	if coll_xy and 
	not coll_x and not coll_y then
		--prevent stuck in corners 
		p.dx *= -p.bounce
		p.dy *= -p.bounce
	end
end
-->8
--player
function make_player(x,y,sp)
	local p = {
		x=64*8,
		y=30,
		dx=0,
		dy=0,
		
		g=0.15,
		spd=0.4,
		jumpspd=2.5,
		fric=0.8,
		bounce=0.01,
		isgrounded=false,
		
		life=10,
		hunger=10,
		
		inv={},
		invs=1,
		maxinv=12,
		
		bx=2,
		by=2,
		bw=4,
		bh=5,
		
		sp=sp,
		sp_y=0,
		isalex=false,
		flp=false,
		
		anim_spr={[0]=64,65},
		anim_frame=0,
		anim=0,
		animspd=10,
		
		walking=false,
		
		cu={},
	}
	for i=1,p.maxinv do
		add(p.inv,{i=0,q=0})
	end
	
	p.update = update_player
	p.draw = draw_player
	
	return p
end

function update_player(p)
	if(btnp(❎))craft_active=not craft_active
	if not craft_active then
		move_player(p)
		interact_world_player(p)
		update_inv(p)
		
		update_camera(p)
		update_anim(p)
	end
end

function draw_player(p)
	if abs(p.dx)<1 then
		p.flip = (p.cu.x<p.x)
	end
	spr(p.sp, p.x,p.y-p.sp_y,1,1,p.flp)
	
	--ui
	--hotbar
	palt(0,false)
	palt(12,true)
	for i=0,p.maxinv-1 do
		
		sspr(104,48,8,8,
		     camx+i*10+4,camy+4,10,10)
		
		local it=p.inv[i+1]
		if it.i>0 and it.q>0 then
			spr(it.i, camx+i*10+5,camy+5)
			if it.q > 1 then
				prints(it.q,camx+i*10+4,camy+8)
			end
		end
		
	end
	rect(camx+3,  camy+3,
	     camx+124,camy+14,1)
	palt()
	
	--selection
	local x = p.invs
	spr(108,camx+x*10-9,camy+1)
	spr(108,camx+x*10-2,camy+1,1,1,true)
	spr(108,camx+x*10-9,camy+9,1,1,false,true)
	spr(108,camx+x*10-2,camy+9,1,1,true,true)
	
	--life & hunger
	for i=1,5 do
		local s=84
		if(i*2<=p.life) s=82
		if(i*2-1==p.life)s=83
		spr(s,camx+i*6-3,camy+17)
		
		s=87
		if(i*2<=p.hunger) s=85
		if(i*2-1==p.hunger) s=86
		spr(s,camx-i*6+126,camy+17)
	end
end

function update_anim(p)
	p.anim += 1
	if p.anim >= p.animspd then
		p.anim = 0
		
		p.anim_frame += 1
		p.anim_frame %= #p.anim_spr+1
		
		p.sp_y = p.anim_frame 
	end
	if not p.walking then
		p.anim_frame=0
		p.sp_y = 0
	end
	
	p.sp=p.anim_spr[p.anim_frame]
end

function interact_world_player(p)
	local i = p.cu.i --TODO:change to b
	
	--mining
	if p.cu.lclk and
	fget(i, breakable) then
		p.cu.timer += 1
		add(particles,mine_ptc(
		p.cu.x*8,p.cu.y*8,block(i).col))
		
		local b = block(i) 
		if p.cu.timer>b.t*0 then
			-- put item in inv
			give_item(b.drop,1,p)
		end
	end
	
	--interacting/placing
	if p.cu.rclk then
		local item = p.inv[p.invs]
		local x,y = p.cu.x,p.cu.y
		local target=mget(x,y)
		
		--placing blocks
		if (p.cu.i==0 or p.cu.i==29) 
		and not rectcoll(p.x+p.bx,
		p.y+p.by, p.bw,p.bh, 
		{p.cu.x,p.cu.y}) then
			
			mset(x,y,item.i)
			p.inv[p.invs].q -= 1
			
			if item.i==14 then
				add_furnace(x,y)
			end
			
		end
		
		--interacting
		if target==13 then
			craft_active = true
		end
	end
end

function update_inv(p)
	p.invs += mscrl
	p.invs = (p.invs-1)%p.maxinv+1
	for i in all(p.inv)do
		if(i.q<=0)i.q=0; i.i=0
	end
end

function update_camera(p)
	local dx = mx-64
	local dy = my-64
	
	camx = flr(p.x-64 + dx\3)
	camy = flr(p.y-64 + dy\3)
	
	camx = min(max(0,camx),896)
	camy = min(max(0,camy),384)
end

function give_item(i,q,p)
	local slot=find_empty_slot(
	p.inv,p.invs,p.maxinv,i)
	
	if slot > 0 then
		p.inv[slot].i = i
		p.inv[slot].q += q
		mset(p.cu.x,p.cu.y,0)
	end
end

function find_item(i,q,p)
	local k = 1
	for v in all(p.inv)do
		if(v.i==i and v.q>=q)return k
		k += 1
	end
	return 0
end

function find_empty_slot(inv,s,maxinv,item)
	if inv[s].q==0 or 
	inv[s].i==item then
		return s
	end
	
	for i=1,maxinv do
		if inv[i].q==0 or 
		inv[i].i==item then
			return i
		end
	end
	return -1
end

function move_player(p)
	p.walking=false
	if btn(⬅️,1)then--or btn(⬅️,0)then
		p.dx-=p.spd
		p.flp=true
		p.walking=true
	end
	if btn(➡️,1)then--or btn(➡️,0)then
		p.dx+=p.spd
		p.flp=false
		p.walking=true
	end
	p.dx *= p.fric
	
	--jumping
	if (btn(⬆️,1)) --or btn(⬆️,0))
	and p.grounded then 
		p.dy=-p.jumpspd
	end
	
	p.dy += p.g
	--p.dy *= p.fric
	
	collide(p)
	
	p.x += p.dx
	p.y += p.dy
end

--cursor
function make_cu()
	local cu={
		x=0,
		y=0,
		sp=110,
		lclk=false,
		rclk=false,
		mclk=false,
		
		i=0,--target
		
		timer=0,
	}
	cu.update = update_cu
	cu.draw = draw_cu
	return cu
end

function update_cu(cu)
	local newx=(mx+camx)\8
	local newy=(my+camy)\8
	if newx!=cu.x or newy!=cu.y then
		--reset cursor
		cu.timer = 0
	end
	cu.x = newx
	cu.y = newy
	cu.lclk=mlc
	cu.rclk=mrc
	cu.mclk=mmc
	
	cu.i = mget(cu.x,cu.y)
end

function draw_cu(cu)
	spr(cu.sp,cu.x*8-1,cu.y*8)
	spr(cu.sp+1,cu.x*8+7,cu.y*8)
	spr(80,mx+camx-1,my+camy-1)
end


-->8
--world
tree=split([[
0,6,6,6,0,
6,6,6,6,6,
6,6,6,6,6,
0,0,5,0,0,
0,0,5,0,0,
0,0,5,0,0
]])

function plant_tree(x,y)
	local i=0
	for b in all(tree) do
		if b!=0 then
			mset(x+(i%5)-2, y+(i\5)-5, b)
		end
		i+=1
	end
end

function blk(mtime,drop,col,scol)
	return {t=mtime,drop=drop,
	col=col,scol=scol}
end

blocks={
--        t drp col scol
	[0] =blk(0, 0, 12,12),
	[1] =blk(60,1, 13,5),--cobble
	[2] =blk(20,3, 4, 2),--dirt
	[3] =blk(20,3, 4, 2),
	[4] =blk(20,3, 4, -1),--grass block
	[5] =blk(50,21,4, 2),--ghost log
	[6] =blk(10,22, 3, 1),--leaves
	[7] =blk(60,6, 2, 2),--planks
	[8] =blk(20,8, 7, 7),--glass
	[9] =blk(60,1, 13, 5),--stone
	[13]=blk(60,13,4, 2),--craft
	[16]=blk(0, 16,8, 2),--tnt
	
	[21]=blk(50,21,4, 2),--solid log
	[22]=blk(0, 22,3, 12),--sapling
	
	[25]=blk(30,24,4, 12),--ladder
	
	[29]=blk(0, 96,3, 12),--grass
	[30]=blk(-1,30,30,1),--bedrock
	
	[48]=blk(60,122,0,5),--coal
	[49]=blk(60,49,15,5),--iron
	[50]=blk(60,50,10,5),--gold
	[51]=blk(60,125,12,5),--diamond
	[52]=blk(60,126,8,5),--restone
}

function block(n)
	if(blocks[n]==nil)return blk(0,0,0)
	return blocks[n]
end

function gen_world()
	for x=0,ww do
		local n1 = noise_1d(x-300,6)*2
		local n2 = noise_1d(x,3)*1
		local h = flr(n1+n2+32)
		grassh[x] = h
		
		--ground
		for y=h,  h+3 do
			mset(x,y,3)
		end
		for y=h+4,wh do
			mset(x,y,9)
		end
		mset(x,h,4)
		
		--grass & trees
		local r=random_point(x)
		local r*=noise_1d(x-300,3)
		if r>0 then
			mset(x,h-1,29)
		end
		if r>0.7 then
			plant_tree(x,h-1)
		end
		
		ores = {
			[48]={t=0.7,s=7},--coal
			[49]={t=0.7,s=7},--iron
			[50]={t=0.7,s=7},--gold
			[51]={t=0.7,s=7},--diamond
			[52]={t=0.7,s=7},--redstone
		}
		
		for y=h,127 do
			--ores
			if y>h+3 then
			for i,v in pairs(ores)do
				local n3=noise(x,y+i*20,v.s)
				if v.t < n3 then
					mset(x,y,i)
				end
			end
			end
			
			--caves
			local yy=min(1,y/42)
			
			local n1=noise(x,y,15)*2*yy
			local n2=noise(x,y,10)*yy
			local n = n1+n2
			n += y/256
			if 1.45<n and n<1.60 then
				mset(x,y,0)
			end
		end
		
		--bedrock
		mset(x,63,30)
		if(r>0) mset(x,62,30)
	end
end

function draw_world()
	--bg tiles
	darkpal()
	for x=max(camx\8-1,0),camx\8+16 do
		for y=grassh[x],camy\8+16 do
			if mget(x,y)==0 then
				local s=3
				if(y>grassh[x]+3)s=9
				if(y==grassh[x])s=4
				spr(s,x*8+3,y*8) 
			end
		end
	end
	pal()
	
	--side tiles
	for x=camx\8-1,camx\8+15 do
		for y=camy\8,camy\8+16 do
			
			local b = block(mget(x,y))
			if b.scol!=12 and
			not fget(mget(x+1,y),solid)and
			not fget(b,transparent) then
				
				pal(3,b.scol)
				pal(2,b.scol)
				if(b.scol==-1) pal() 
				spr(31,x*8+8,y*8)
				pal()
			end
			
			--diamond blue
			if mget(x,y)==51 then 
				spr(51,x*8,y*8)
			end
		end
	end
	
	palt(0,false)
	palt(12,true)
	map(0,0,0,0,ww,wh)
end

-->8
--crafting & ui
-- crafting
function recipe(res,q,items)
	--inspiration:islander by carson kompon
	local items=split(items,"|")
	local t={res={i=res,q=q}}
	for i in all(items)do
		local item = split(i)
		add(t,{i=item[1],q=item[2]})
	end
	return t
end

crafts = {
	recipe(7,4,"21,1"),--planks
	recipe(97,4,"7,1"),--stick
	--wood pick
	recipe(112,1,"97,2|7,3"),
	recipe(13,1,"7,4"),--crfttable
	recipe(14,1,"1,8"),--furnace
	recipe(27,1,"7,8")
}

function make_craft_menu()
	craft_sel = 1
	craft_active = false
end

function update_craft_menu(ply)
	if(btnp(⬆️,1))craft_sel -= 1
	if(btnp(⬇️,1))craft_sel += 1
	craft_sel=(craft_sel-1)%#crafts+1
	
	local item=crafts[craft_sel] 
	
	if btnp(🅾️) then
		local cancraft = true
		for i in all(item)do
			cancraft=cancraft and
			  (find_item(i.i,i.q,ply)>0)
		end
		
		if cancraft then 
			give_item(item.res.i, 
			item.res.q, ply)
			for i in all(item) do
				local f=find_item(i.i,i.q,ply)
				ply.inv[f].q-=i.q
			end
		end
	end
end

function draw_craft_menu(x,y)
	--local x,y,w,h=m.x,m.y,m.w,m.h
	local w,h=30,30
	local col,scol=6,13
	
	local c = crafts[craft_sel]
	local h = #c*10 + 18
	y -= h
	local m = y+h\2
	
	rectfill(x,y, x+w,y+h, col)
	rect(x,y, x+w, y+h, scol)
	
	for i=1,#crafts[craft_sel] do
		local iy = y+(i-1)*10 + 10
		sspr(104,48,8,8,
			      x+2,iy, 10,10)
		spr(c[i].i,
			      x+3,iy+1)
		prints(c[i].q, x+2, iy+4)
	end
	
	--result
	spr(88,x+13,m-2)
	
	sspr(104,48,8,8,
			      x+19,m-4, 10,10)
	spr(c.res.i, x+20,m-3)
	prints(c.res.q, x+19,m)
	prints("🅾️",x+w-10, m+6)
	
	prints("⬆️",x+4,y+2)
	prints("⬇️",x+4,y+h-7)
	
	print("❎",x+w-4,y-1, 2)
	print("❎",x+w-4,y-2, 8)
	
	--scroll bar
	rectfill(x,y,x-2,y+h,13)
	local sw = 2
	local index = (craft_sel-1) 
	local sy = y+1+sw+
	((h-sw*2-2) / (#crafts-1)) * index
	rectfill(x-1,sy-sw,x-1,sy+sw,7)
end

--furnace
function make_furnace()
	return {
		input={i=0,q=0},
		fuel={i=0,q=0},
		prod={i=0,q=0},
		
		fuelprog=0,
		maxfuelprog=0,
		prog=0,
		maxprog=0,
		active=false,
	}
end

function add_furnace(x,y)
	furnaces[pos2id(x,y)]=make_furnace()
end

function update_furnace(f)
	if f.fuel.q>0 
	or f.input.q>0 then
		f.prog += 1
		f.fuelprog += 1
		if f.fuelprog>=f.maxfuelprog then
			f.fuel -= 1
			f.fuelprog = 0
		end 
		if f.prog >= p.maxprog then
			f.fuel.q -= 1
			f.prog = 0
			
			f.prod.q += 1
			f.prod.i = prod(f.input.i)
			f.input.q -= 1
		end
	end
end

function prod(n)
	local t={
		[49]=123,
	}
	if(t[n]==nil)return 1
	return t[n]
end

function pos2id(x,y)
	return y*128 + x
	--return (y<<7)|x
end

function id2pos(id)
	return {x=id%128,y=id\128}
end

function get_furnace(x,y)
	
end

-->8
--perlin noise
function lerp(a0, a1, w)
	return (a1 - a0) * w + a0
end

function smoothstep(a0, a1, w)
	--return (a1 - a0) * w + a0; -- linear interpolation >> (uglier result but faster)
	return (a1-a0)*(3.0-w*2.0)*w*w + a0  -- cubic
end

function random_point(ix)
	-- random float between [-1;1]
	ran = 29200.563 * sin(
	       ix * 344.43242 + 
	       seed * 8912.234
	      ) * cos(
	       ix * 2157.234 +
	       seed * 19758.34455
	      )
	return ran % 2 - 1
end

function noise_1d(x,scale)
	-- returns between [-1;1] 
	x /= scale
	
	x0 = random_point(flr(x))
	x1 = random_point(flr(x)+1)
	return smoothstep(x0, x1, x-flr(x)) * 2 - 1
end

function v2(x,y)
	--2d vector
	return {x=x,y=y}
end

function random_grid(ix,iy)
	-- random float. no precomputed gradients mean this works for any number of grid coordinates
	-- readapted from source c code: https://en.wikipedia.org/wiki/perlin_noise
	ran = 29200.563 * sin(
	      ix*344.43242 + 
	      iy*13245.345 + 
	      seed*21312.1231) * 
	     cos(
	      ix*2157.234 + 
	      iy*2172.199 + 
	      seed*19758.34455)
	return v2(cos(ran), sin(ran))
end

function noise(x,y,scale)
	-- returns perlin noise value 
	-- for (x, y)
	x /= scale
	y /= scale
	
	--  (x0,y0) - (x1,y0)
	--  |         |
	--  (x0,y1) - (x1,y1)
	x0 = flr(x)
	x1 = x0 + 1
	y0 = flr(y)
	y1 = y0 + 1
	
	-- compute weights for interpolation for later on
	sx = x - x0
	sy = y - y0
	
	-- compute dot products of vectors in nearby grids
	v0 = random_grid(x0, y0)
	d0 = v2(x - x0, y - y0)
	dot0 = v0.x * d0.x + v0.y * d0.y
	
	v1 = random_grid(x1, y0)
	d1 = v2(x - x1, y - y0)
	dot1 = v1.x * d1.x + v1.y * d1.y
	
	s0 = smoothstep(dot0, dot1, sx)
	
	v0 = random_grid(x0, y1)
	dot0 = v0.x * (x - x0) + v0.y * (y - y1)
	v1 = random_grid(x1, y1)
	dot1 = v1.x * (x - x1) + v1.y * (y - y1)
	
	s1 = smoothstep(dot0, dot1, sx)
	val = smoothstep(s0, s1, sy)
	
return (val+1)/2
end
-->8
--background
function draw_sky()
	--sun/moon
end

function create_background()
	background = {}
	bg_flora = {}
	for x=0,ww*2 do
		--ground
		local n1=noise_1d(x+200,6)*2
		local n2=noise_1d(x+300,3)*1
		local y = n1+n2+32
		background[x] = flr(y)
		
		--grass & trees
		local r=random_point(x)
		if r>0.8 then
			bg_flora[x]=2--tree
		elseif r>0 then
			bg_flora[x]=1--grass
		else
			bg_flora[x]=0
		end
	end
end

function draw_background()
	local p = 4
	local px = camx/p
	local py = camy/p
	
	--todo: only part in camera
	for i=0,#background do
		local x = i*4 + px
		local y = background[i]*4 + py
		rectfill(x,
		y + 48,
		x+3,
		camy+128 + py,
		13)
		
		if bg_flora[i]==2 then
			--draw tree
			for j=0,#tree-1 do
				local b=tree[j+1]
				if b!=0 then
					local bx=x+((j%5)-2)*4
					local by=y+((j\5)+6)*4
					rectfill(bx,by,bx+3,by+3)
				end
			end
		end
	end
end

--[[
function plant_tree(x,y)
	local i=0
	for b in all(tree) do
		if b!=0 then
			mset(x+(i%5)-2, y+(i\5)-5, b)
		end
		i+=1
	end
end]]

__gfx__
001d82ec77d776664444444444444444bb3bbb3b444244443bbbb3b322222222777777c766666666000000000021100044444444414114145555555555555555
105d94fcdddd776642224444422244443b3b3b3b42424244b3333333244424447ccccccc666ddd6600000000021001004cc4cc42441111445dddddd55dddddd5
218daafc7666dddd44444444444444443b3b2b3242444244b33b3331244424447cc7ccc766666666000000000100000044444442424112225d0000d55d0000d5
31bdb3fc766d766d44d224444444422432b2422242444444b3b33331244424447c7cccc76666666600000000000002104cc4cc42424112425d0000d55d0000d5
429ccd6cddd7666644444444444444442222442444424244b3333331222222227cccccc76ddddd660000000000000100444444f24241166d5666666556666665
51ddd56d66d7666d4444442244444444244444444442442433333331442444247cccccc76666666600000000021100004224224266d1166d56600665566a9665
6d7ce8fc666d66d64442d444442224444444224424424424b333333144244424ccccccc766666ddd00000000211000214444444266d116d45600006556a9a965
767cf47c666ddd662244444444444444444444442444442433111113442444247c77777766666666000000000100011042222224444114445555555555555555
8882888211111111a99999aa000000000000000044424444cccccccc00000000cccccccc42cccc420000000022222222ffffffffcccccccc5551115533300000
888288821111111199aa988a000000000000000042424244cc3333cc0000000044444442422222420000000024444442ffffffffccc3c3ccddd5555533300000
77777777111111119aaa9889000000000000000042444244c3b3331c0000000041141442421111420000000024765442f77fffffc3c3c3c35111555532300000
756565571111111188a99899000000000000000042444444c332321c000000004111114242cccc420000000022765222ffffffffc3ccc3c355555ddd22300000
755655571111111188999998000000000000000044424244c322231c000000004141114242cccc420000000024665442ffffffffcc3c3ccc5551111122200000
77777777111111118999aa98000000000000000044424424cc3221cc0000000044444442422222420000000024444442ffffff773c3c3c3cdd55555522200000
88828882111111119998aa99000000000000000024424424ccc42ccc00000000ccc22ccc421111420000000024444442ffffffff3c33cc3c5111155522200000
8882888211111111a998899a000000000000000024444424ccc42ccc00000000ccc42ccc42cccc420000000022222222ffffffffc3c3c3cc5555ddd522200000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
016ddd10fe6dddefa76ddd7ac76ddd7c8e6ddde80000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00066100fff66effa99667aaccc667cc88266e880000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666666666666666666666666666666666666660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6dd100666ddeff666dd7a9666dd7cc666dde82660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
6610066666eff666667a9666667cc66666e826660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
66666ddd66666ddd66666ddd66666ddd66666ddd0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
610666666ef6666667a6666667c666666e8266660000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
22244444222444444449999944499999333333303333333055666dd055666dd033bbbbb033bbbbb01100000cc100000c00000000000000000000000000000000
2224fff42224fff444499ff944499ff9333bbb30333bbb3055666660556666603311b1103311b1101100000cc100000c00000000000000000000000000000000
22e71f1722e71f1744e73f3744e73f3733bbbbb033bbbbb0555565505555655033113110331131101172027cc172027c00000000000000000000000000000000
22effeff22effeff44efffff44efffff3311b1103311b1105566d6405566d64033b111b033b111b01100000cc100000c00000000000000000000000000000000
2eef444f2eef444f444ffeff444ffeff33b333b033b333b0556555645565556433b1b1b033b1b1b01000000c1000001c00000000000000000000000000000000
0dccccc00dccccc003999bb003999bb00333bc3b0333bc3b05dd6dd605dd6dd603bbbb0003bbbb001000000c1000001c00000000000000000000000000000000
0efcccf0efdcccef0efbbbf0ef3bbbef03cccc0003cccc000566660405666604333bbbb0333bbbb0c10c10ccc10c10cc00000000000000000000000000000000
001d1d0001d001d00024240002400240013013001300013005605640560005603b3d3d303b3d3d30c10c10ccc10c10cc00000000000000000000000000000000
011000000001100008080000080000000000000004240000042000000000000000d0000000000000000000000000000000000000000000000000000000000000
17110000001711008e8880008e81000001010000444440004441000001110000dddd000000000000000000000000000000000000000000000000000000000000
1771100001171100888880008881100011111000444240004441100011111000ddddd00000000000000000000000000000000000000000000000000000000000
1777110017177711288820002881100011111000424440004241100011111000dddd500000000000000000000000000000000000000000000000000000000000
177771100177771102820000028100000111000024442000244110001111100055d5000000000000000000000000000000000000000000000000000000000000
17711100001771100020000000200000001000000222000002210000011100000050000000000000000000000000000000000000000000000000000000000000
01171100001771100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00011000000111000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
ddddbddddddddddd00000000000000000000000000000000000000000000000000000000000000000000000000000000000000001555555d7771077711711000
dbdddbddddd42ddd00000000000000000000000000000000000000000000000000000000000000000000000000000000007777775dddddd67100000710071000
3bddd3dddd442ddd00000000000000000000000000000000000000000000000000000000000000000000000000000000076ddddd5dddddd67100000710071000
33dddddbddd42ddd0000000000000000000000000000000000000000000000000000000000000000000000000000000007d000005dddddd60000000000000000
dddb3ddbddd443dd0000000000000000000000000000000000000000000000000000000000000000000000000000000007d000005dddddd60000000000000000
3dd33db3ddd42ddd0000000000000000000000000000000000000000000000000000000000000000000000000000000007d000005dddddd67100000710071000
3ddddd33ddd42ddd0000000000000000000000000000000000000000000000000000000000000000000000000000000007d000005dddddd67100000710071000
d3dddbdddddddddd0000000000000000000000000000000000000000000000000000000000000000000000000000000007d00000d66666677771077711711000
ddb4b2ddddb5b1dddd7765dddd77c1ddddd42dddddd51dddddd75dddddd71ddd0000000000000000dd00dddddddddddddddddddddd1111dddddddddd0044f400
d44b442dd55b551dd766665dd7cccc1dddd442ddddd551ddddd765ddddd7c1dd0000000000000000d0550ddddddd777ddddda7add1c77c1dddd11ddd07777770
443434425534355166542665cc142cc1ddd442ddddd551ddddd765ddddd7c1dd0000000000000000055110ddddd77767ddda7a9ad17ccd1ddd1821dd0744f470
42d42d4251d42d5165d42d65c1d42dc1ddd442ddddd551ddddd665dddddcc1dd00000000000000000511010ddd777676dda7a9a9177ccdc1d182821d00700700
ddd42dddddd42dddddd42dddddd42dddddd442ddddd551ddddd765ddddd7c1dd000000000000000001011100d7776766da7a9a9917cddcc11888822107e78e70
ddd42dddddd42dddddd42dddddd42dddddd4b3ddddd5b3ddddd665dddddcc1dd0000000000000000001100007666766da999a99d17dccdc1182882217e7888e7
ddd42dddddd42dddddd42dddddd42ddddd4b442ddd4b442ddd44442ddd44442d0000000000000000d000000d666666dd999999ddd1dccd1dd188221d7e8888e7
ddd42dddddd42dddddd42dddddd42dddddd442ddddd442ddddd442ddddd442dd0000000000000000dd000ddd66666ddd99999ddddd1111dddd1111dd07777770
__label__
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
ccc77777777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cc76ddddddddd6711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111ccc
cc7d155555555d755555555d155555555d155555555d155555555d155555555d155555555d155555555d155555555d155555555d155555555d155555555d1ccc
cc7d53bbbb3b3d7dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd61ccc
cc7d5b3333333d7dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd61ccc
cc7d5b33b3331d7dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd61ccc
cc7d773b77737d7dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd61ccc
cc7d173371737d7dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd61ccc
cc7d573373737d7dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd61ccc
cc7d573373737d7dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd61ccc
cc7d777177717d7dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd65dddddddd61ccc
cc7d111611161d7666666667d666666667d666666667d666666667d666666667d666666667d666666667d666666667d666666667d666666667d6666666671ccc
cc76ddddddddd6711111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111ccc
ccc77777777777cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc
cccc8c8ccc8c8ccc8c8ccc8c8ccc8c8ccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddd424dcc424ccc424ccc424ccc424cccc
ccc8e888c8e888c8e888c8e888c8e888cccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddd44444c44444c44444c44444c44444ccc
ccc88888c88888c88888c88888c88888cccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddd44424c44424c44424c44424c44424ccc
ccc28882c28882c28882c28882c28882cccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddd42444342444b42444b42444b42444111
cccc282ccc282ccc282ccc282ccc282ccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddddd24442b24442324442324442324442111
ccccc2ccccc2ccccc2ccccc2ccccc2cccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddd222db3222331222b3322233b2221111
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddddddddddb3b33331b3b33331b3b33331111
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddddddddddb3333331b3333331b3333331111
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddddddd333333313333333133333331111
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddddddddddb3333331b3333331b3333331111
cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddddddd331111133311111333111113111
bb3b3111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddd3bbbb3b33bbbb3b33bbbb3b33bbbb3b33bb
33333111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddddddccccb3333333b3333333b3333333b3333333b33
b3331111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddddddccccb33b3331b33b3331b33b3331b33b3331b33
33331111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddddddccccb3b33331b3b33331b3b33331b3b33331b3b
33331111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddddddccccb3333331b3333331b3333331b3333331b33
33331111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddddddddddd33333331333333313333333133333331333
33331111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddddddddddddddb3333331b3333331b3333331b3333331b33
11113111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddddddddddd33111113331111133311111333111113331
bb3b33bbbb3b3111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccdddddddddddddddddddd3bbbb3b33bbbb3b33bbbb3b33bbbb3b33bb
33333b3333333111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddddddddddddddb3333333b3333333b3333333b3333333b33
b3331b33b3331111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddddddddddddddb33b3331b33b3331b33b3331b33b3331b33
33331b3b33331111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddddddddddddddb3b33331b3b33331b3b33331b3b33331b3b
33331b3333331111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddddddddddddddddddb3333331b3333331b3333331b3333331b33
3333133333331111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddcccccccc33333331333333313333333133333331333
33331b3333331111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddccccccccb3333331b3333331b3333331b3333331b33
1111333111113111cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccddddcccccccc33111113331111133311111333111113331
bb3b33bbbb3b3111ccccccccccccccccccccccccc44444222cccccccccccccccccccccccccccc3bbbb3b33bbbb3b33bbbb3b3111ddddd44424444222dddddccc
33333b3333333111ccccccccccccccccccccccccc4fff4222ccccccccccccccccccccccccccccb3333333b3333333b3333333111ddddd42424244222dddddccc
b3331b33b3331111ccccccccccccccccccccccccc71f17e22ccccccccccccccccccccccccccccb33b3331b33b3331b33b3331111ddddd42444244222dddddccc
33331b3b33331111cccccccccccccccccccccccccffeffe22ccccccccccccccccccccccccccccb3b33331b3b33331b3b33331111ddddd42444444222dddddccc
33331b3333331111cccccccccccccccccccccccccf444fee2ccccccccccccccccccccccccccccb3333331b3333331b3333331111ddddd44424244222dddddccc
3333133333331111cccccccccccccccccccccccccccccccdcccccccccccccccccccccdddddddd333333313333333133333331111ddddd44424424222dddddddd
33331b3333331111ccccccccccccccccccccccccccfcccfecccccccccccccccccccccddddddddb3333331b3333331b3333331111ddddd24424424222dddddddd
1111333111113111cccccccccccccccccccccccccccd1d1ccccccccccccccccccccccdddddddd331111133311111333111113111ddddd24444424222dddddddd
ccccccccccccccccccccccccccccc3bbbb3b33bbbb3b33bbbb3b3111ccccccccccccc3bbbb3b33bbbb3b33bbbb3b33bbbb3b33bbbb3b344424444222dddddddd
cccccccccccccccccccccccccccccb3333333b3333333b3333333111dddddddddddddb3333333b3333333b3333333b3333333b333333342424244222dddddddd
cccccccccccccccccccccccccccccb33b3331b33b3331b33b3331111dddddddddddddb33b3331b33b3331b33b3331b33b3331b33b333142444244222dddddddd
cccccccccccccccccccccccccccccb3b33331b3b33331b3b33331111dddddddddddddb3b33331b3b33331b3b33331b3b33331b3b3333142444444222dddddddd
cccccccccccccccccccccccccccccb3333331b3333331b3333331111dddddddddddddb3333331b3333331b3333331b3333331b333333144424244222dddddddd
cdddddddddddddddddddddddddddd333333313333333133333331111ddddddddddddd333333313333333133333331333333313333333144424424222dddddddd
cddddddddddddddddddddddddddddb3333331b3333331b3333331111dddddddddddddb3333331b3333331b3333331b3333331b333333124424424222dddddddd
cdddddddddddddddddddddddddddd331111133311111333111113111ddddddddddddd331111133311111333111113331111133311111324444424222dddddddd
cdddddddddddddddddddd3bbbb3b33bbbb3b33bbbb3b33bbbb3b33bbbb3b3111ddddd3bbbb3b33bbbb3b33bbbb3b33bbbb3b33bbbb3b344424444222dddddddd
dddddddddddddddddddddb3333333b3333333b3333333b3333333b3333333111dddddb3333333b3333333b3333333b3333333b3333333424242442223d3ddddd
dddddddddddddddddddddb33b3331b33b3331b33b3331b33b3331b33b3331111dddddb33b3331b33b3331b33b3331b33b3331b33b3331424442442323d3d3d3d
dddddddddddddddddddddb3b33331b3b33331b3b33331b3b33331b3b33331111dddddb3b33331b3b33331b3b33331b3b33331b3b3333142444444232dd3d3d3d
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
ddddddddddddddddddddddddddddd3333ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
dddddddddddddddddddddddddddd333333ddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd33333
dddddd333ddddddddddddddddddd333333dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd333333
ddddd33333dddddddddd33333333dd33333ddddddddddddddddddddddd333333ddddddddddddddddddddddddd333dddddddddddddddddddddddddddddd333333
ddddd33333ddddddddd3333333333d33333333ddddddddddddddddddd33333333ddd333ddd333ddddddddddd33333ddd333ddddddddddddddddddddddddd4dd4
ddddddd4ddddddddddd3333333333d444d33333dddddddddddddddddd333333333d33333d33333dddddddddd33333dd33333dddddddddddddddddddddddd4dd4
ddddddd4dddbbdddddddd4d44d4ddbbb4d33333ddd3333ddddddddddddd4d33333d33333d33333dddddddd333d4dddd33333dddddddddddddddddddddddd4dd4
ddddddd4dbb44bbdddddd4d44d4dd4444ddd4dddd3333333ddddddddddd4dd44ddddd4ddbdd4dddd333dd333334dddddd4ddddddddddddddd333ddddddddbbbb
ddddddbbb444444bddddd4d44d4db444bddd4dddd33333333dddddddddd4dd44ddddd4db4bd4ddd33333d333334dddddd4dddddddddddddd33333dddddbb4444
dddddb4444444444bdddbbbbbbbb44444bbb4dddddd433333dddddbbbbbbbbb4ddddd4b444b4ddd333333dd4ddbbbdddd4ddddddddddbddd33333dbbbb444444
ddddd444444664444bbb4444444446664444bbbbbdd44d4dddddbb444444444bdddddb44444bbbbd33333dd4db444bbbbbddddddddbb4bbddd4ddb4444444444
ddddb444466666644444444444444666444444444bd44d4ddddb444444444444dddddd446444444bd44dddd4b444444444dddddddb44444bdd4db44444446666
dddd44666666666644444444444466666444444444bbbd4dddb4444444444444bdddddd666444444b44ddddb4444444444bdddddd4444444bd4b444444666666
ddbb4666666666666444666666666666666ddd4444444bbbbb444466666666644bdb4d66666444444b4dddb444666444444bbdddb44464444bb4446666666666
bb4446666666666dddd666666666666666dddddd64444444444466666666666644b446666666660444bbbb444666666666444bbb446666f444444666666666aa
4444ccc66666666dddddd6666666666666dddddddd44444444d666666666666644446666666666664444444466666666664444444666666644448866ddddd6aa
4444ccc6666666dddd6dddd86666666666dd66666ddddddddddddd68888888888444666666666666644444dddddd666666644444466ddddddddddddddddddd66
446ccc66666666ddd66666ddd666666666dd6666666dddd66666ddd886668888664f6666666666666644dddddddddddd6666644ddddddddddddddd866666ddd6
6666c666666666dd66666666dd6666666dd666666666666666660dd66666666666ff6666666666666ddddd666666ddddddddddddd666aa666668886666666ddd
66666600668866dd666666666fdd666ffdd6666666666666666666dd666666666666666666666666dd06666666666666ddddddd66666666666668006666666dd
ffff6000668866dd666666666ffdddfddd666666666666666666666d66666666666666666666666dd66666666666666666dddd66666666666666666666666666
aaff0066666666ddd66666666ffffddddd666666666666666666666dd666666666666666666666dd666666c666a6666666666666666666666668666666666666
aaa60666666666ddd66666666fff666ff66666666666666666666666dd666666666666666666ccd6666666c66aa66666666666666666666666666666666666cc
66666666666666ddd6666666666666666666666666666666666666666ddd6dd6666666686ffccdd6666666c66666666668888ff66666666666666666666666cc
6666666666666ddd66666666666666666666666666666666666666666666ddddd666666888666d66666666666666666668888ff6666666666666a66666666666
dd606666666666dd66666666666666668dddddddddddd666666666666666c6ddd666666688666d666666666666666666666688f6666666666666666666666666
6ddddddddddd6ddd6666666666666666dddd66aa6dddddd666666666666cc66dd66666666886dd66666666666666666666666fa0000666666666666666666666
666ddddddddddddd6666666666666666dd666aaaa66ddddd666666666000666d666666666886d666666666666666666666666fa0000066666668866666666666
66666ddddddddddd666666666666666ddd666aaaaa6666ddd66666666600666d6666666666dd6666666666666666666c66666ff6a66666666668666666666aaa
cc6666dddddddddd666666666666666dd666666aaa66666dd66666666666666d666666666dd666666666666666cccccccc6ddd66ccc66666668ddddd666666aa
cccc6666dddddddd6666666666666666dd66666666886666dd6666666666668d86666666dd6666666666666666ccccccccddddd6ccc666666ddddddd66666666
66cc666666dddddddff6666666666666dd66666668886666dd666666666666dd8666666dd666666666666666666666666dddddddd666666ddddddddd66666666
6666666666dddddddff66666666666666dd66666666666666d666666666666d6666666dd6666666666666666ddddd6666dddddddddddddddd6666ddd66666666
6666666666ddddddd66666666666666666dd66666666f6666d666666666666d6666666d66666666666f6666ddddddd666dddddddddddddddd6666ddd66666666
66666666666ddddddd666666666666688666dd6666fff6666d666666666666d666666dd66666666666ff66dd666dddd86dddddddddddddddd66ccdd6666666ff
666aaaa66666dddddd6666666666668886666dd666f666666dd66666666666d66666dd6666666666666666d66666dddd66dddddddddddddddd6dddd6666666ff
666aaaa666666ddddd6666cc66666688866666dddd6666666dd6666ccccccddcc600dd666666666666666dd66666dddd6666666666ddddddddddddc6666666dd
666aaa6666666666d66666ccc666668886666666dddd66666d66666cc666cddc6600dd666666666666666dd66666ddd6666666666666ddddddddccc6666666dd
6666a6666666666666666666666666886666666666ddd666dd66666666666dd66600ddd66666666666666dd66666dd66666666666666fddddd6ccc6666666ddd
6666666666cc66666ddddddddd006660066666666666ddddd666666666666dd666666dddd6666666666666dd66ddd66666666666666666dd6666c66666666ddd
0000666666cc66666dddddd6dddd0000006666666666666666666660666666d66666666ddd666666666666dddddd66666666666666666ddd6666666666666ddd
0000066666666666dddd6666600dd000006666666666666666666660666666d6666666666ddd6666666666a666f666666666666666666dddd66c66666666dddd
fff666666666666ddd6666666000d660066666666666666666666666666666d66666666666ddaa66666666a66ff66666666666666666dddddd6666666666dddd
66666666666666ddd66666666666dd66666666666668888866666666666666d66666666c60dda666666666a6666666666cccc006666dd886ddd66666666ddddd
66665555565555dd656555655556d655566655666885585885555565655566556556556c5565666665565655665558566555c55565555586565d55585d555d55
55555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555555

__gff__
0081818181018181c18100814101010181000000008141004141000081418000000000000000000000000000000000008181818181000000000000000000000000000000000000000100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
