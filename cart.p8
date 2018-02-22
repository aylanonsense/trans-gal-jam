pico-8 cartridge // http://www.pico-8.com
version 16
__lua__

function noop() end

local entities
local player
local scene_frame
local freeze_frames
local buttons
local button_presses
local button_releases

local entity_classes={
	player={
		move_x=0,
		move_y=0,
		radius=8,
		check_collision=true,
		update=function(self)
			-- check inputs
			self.move_x=ternary(buttons[1],1,0)-ternary(buttons[0],1,0)
			self.move_y=ternary(buttons[3],1,0)-ternary(buttons[2],1,0)
			-- adjust velocity
			self.vx=2*self.move_x -- *ternary(self.move_y==0,1,0.7)
			self.vy=2*self.move_y -- *ternary(self.move_x==0,1,0.7)
		end,
		post_update=function(self)
			self.x=mid(self.radius,self.x,120-self.radius)
			self.y=mid(self.radius,self.y,70-self.radius)
		end,
		draw=function(self)
			circ_perspective(self.x,self.y,0,self.radius,8)
		end,
		draw_flat=function(self)
			-- rect(self.x-self.radius+0.5,self.y-self.radius+0.5,self.x+self.radius-0.5,self.y+self.radius-0.5,14)
			circfill(self.x-0.5,self.y-0.5,self.radius-0.5,8)
		end
	},
	passenger={
		radius=8,
		is_obstacle=true,
		draw=function(self)
			circ_perspective(self.x,self.y,0,self.radius,15)
		end,
		draw_flat=function(self)
			-- rect(self.x-self.radius+0.5,self.y-self.radius+0.5,self.x+self.radius-0.5,self.y+self.radius-0.5,12)
			circfill(self.x-0.5,self.y-0.5,self.radius-0.5,1)
		end
	},
	seat={
		width=40,
		height=10,
		is_obstacle=true,
		draw=function(self)
			rect_perspective(self.x+0.5,self.y+0.5,self.x+self.width-1.5,self.y+self.height-1.5,15)
		end,
		draw_flat=function(self)
			rectfill(self.x+0.5,self.y+0.5,self.x+self.width-0.5,self.y+self.height-0.5,1)
		end
	}
}

function _init()
	entities={}
	scene_frame=0
	freeze_frames=0
	buttons={}
	button_presses={}
	button_releases={}
	player=spawn_entity("player",20,20)
	spawn_entity("passenger",30,50)
	spawn_entity("passenger",60,30)
	spawn_entity("seat",5,0)
	spawn_entity("seat",5,60)
	spawn_entity("seat",70,0)
	spawn_entity("seat",70,60)
end

function _update()
	-- keep track of inputs (because btnp repeats presses)
	local i
	for i=0,5 do
		button_presses[i]=btn(i) and not buttons[i]
		button_releases[i]=not btn(i) and buttons[i]
		buttons[i]=btn(i)
	end
	-- freeze frames skip frames
	if freeze_frames>0 then
		freeze_frames=decrement_counter(freeze_frames)
	else
		-- increment counters
		scene_frame=increment_counter(scene_frame)
		-- update entities
		local num_entities=#entities
		for i=1,num_entities do
			local entity=entities[i]
			-- call the entity's update function
			local skip_apply_velocity=entity:update()
			-- call apply_velocity unless update returns true
			if not skip_apply_velocity then
				entity:apply_velocity()
			end
			-- do some default update stuff
			increment_counter_prop(entity,"frames_alive")
			if decrement_counter_prop(entity,"frames_to_death") then
				entity:die()
			end
		end
		-- check for collisions
		for i=1,#entities do
			local entity1=entities[i]
			local j
			for j=1,#entities do
				local entity2=entities[j]
				if i!=j and entity1.check_collision and entity2.is_obstacle then
					local r1,r2=entity1.radius,entity2.radius
					local dx=entity2.x-entity1.x
					local dy=entity2.y-entity1.y
					local square_dist=dx*dx+dy*dy
					-- use circle-based collision detection
					if r1 and r2 then
						local sum_radius=r1+r2
						-- the entities are overlapping
						if square_dist<sum_radius*sum_radius then
							local dist=sqrt(square_dist)
							local dist_to_nudge=sum_radius-dist
							entity1.x-=dist_to_nudge*dx/dist
							entity1.y-=dist_to_nudge*dy/dist
						end
					-- use rectangle-based collision detection
					else
						-- assumes "circle" colliding against rectangular obstacle
						local x1,y1,w1,h1=entity1.x-r1,entity1.y-r1,2*r1,2*r1
						local x2,y2,w2,h2=entity2.x,entity2.y,entity2.width,entity2.height
						-- circle walked down into an obstacle
						if rects_overlapping(x1+3,y1+h1/2,w1-6,h1/2,x2,y2,w2,h2) then
							y1=y2-h1
							entity1.vy=min(0,entity1.vy)
						-- circle walked up into an obstacle
						elseif rects_overlapping(x1+3,y1,w1-6,h1/2,x2,y2,w2,h2) then
							y1=y2+h2
							entity1.vy=max(0,entity1.vy)
						-- circle walked left into an obstacle
						elseif rects_overlapping(x1,y1+3,w1/2,h1-6,x2,y2,w2,h2) then
							x1=x2+w2
							entity1.vx=max(0,entity1.vx)
						-- circle walked right into an obstacle
						elseif rects_overlapping(x1+w1/2,y1+3,w1/2,h1-6,x2,y2,w2,h2) then
							x1=x2-w1
							entity1.vx=min(0,entity1.vx)
						end
						entity1.x=x1+r1
						entity1.y=y1+r1
					end
				end
			end
		end
		-- post update
		for i=1,num_entities do
			local entity=entities[i]
			entity:post_update()
		end
		-- remove dead entities from the game
		local entity
		for entity in all(entities) do
			if not entity.is_alive then
				del(entities,entity)
			end
		end
		-- sort entities for rendering
		for i=1,#entities do
			local j=i
			while j>1 and entities[j-1].render_layer>entities[j].render_layer do
				entities[j],entities[j-1]=entities[j-1],entities[j]
				j-=1
			end
		end
	end
end

function _draw()
	camera()
	cls(1)
	-- camera(-4,-29)
	camera(-4,-2)
	-- let's draw the flat version of the simulation
	rectfill(0,0,119,69,15)
	-- draw all entities
	foreach(entities,function(entity)
		entity:draw_flat()
		pal()
	end)
	-- now draw everything in perspective
	camera(-4,-55)
	rect_perspective(0,0,119,69,15)
	-- draw all entities
	foreach(entities,function(entity)
		entity:draw()
		pal()
	end)
end

function spawn_entity(class_name,x,y,args,skip_init)
	local the_class=entity_classes[class_name]
	local entity
	if the_class.extends then
		entity=spawn_entity(the_class.extends,x,y,args,true)
	else
		-- create default entity
		entity={
			render_layer=10,
			-- lifecycle props
			is_alive=true,
			frames_alive=0,
			frames_to_death=0,
			-- collide props
			check_collision=false,
			is_obstacle=false,
			-- spatial props
			x=x or 0,
			y=y or 0,
			vx=0,
			vy=0,
			radius=nil,
			width=nil,
			height=nil,
			-- entity methods
			init=noop,
			update=noop,
			post_update=noop,
			draw=noop,
			draw_flat=noop,
			draw_sprite=function(self,dx,dy,...)
				draw_sprite(self.x-dx,self.y-dy,...)
			end,
			die=function(self)
				if self.is_alive then
					self:on_death()
					self.is_alive=false
				end
			end,
			on_death=noop,
			-- move methods
			apply_velocity=function(self)
				self.x+=self.vx
				self.y+=self.vy
			end
		}
	end
	-- add class properties/methods onto it
	for k,v in pairs(the_class) do
		entity[k]=v
	end
	-- add properties onto it from the arguments
	for k,v in pairs(args or {}) do
		entity[k]=v
	end
	if not skip_init then
		-- initialize it
		entity:init()
		add(entities,entity)
	end
	-- return it
	return entity
end

-- draws a sprite, assumes no stretching
function draw_sprite(x,y,sx,sy,sw,sh,...)
	sspr(sx,sy,sw,sh,x+0.5,y+0.5,sw,sh,...)
end

-- increment a counter, wrapping to 20000 if it risks overflowing
function increment_counter(n)
	return n+ternary(n>32000,-12000,1)
end

-- increment_counter on a property of an object
function increment_counter_prop(obj,k)
	obj[k]=increment_counter(obj[k])
end

-- decrement a counter but not below 0
function decrement_counter(n)
	return max(0,n-1)
end

-- decrement_counter on a property of an object, returns true when it reaches 0
function decrement_counter_prop(obj,k)
	if obj[k]>0 then
		obj[k]=decrement_counter(obj[k])
		return obj[k]<=0
	end
end

-- if condition is true return the second argument, otherwise the third
function ternary(condition,if_true,if_false)
	return condition and if_true or if_false
end

-- returns true if two axis-aligned rectangles are overlapping
function rects_overlapping(x1,y1,w1,h1,x2,y2,w2,h2)
	return x1+w1>=x2 and x2+w2>=x1 and y1+h1>=y2 and y2+h2>=y1
end

function to_render_coords(x,y,z)
	x-=59.5
	y-=35
	x,y=0.8315*x+0.5556*y,(0.8315*y-0.5556*x)/1.5-(z or 0)
	return x+59.5,y+35
end

function circ_perspective(x,y,z,r,c)
	local i
	for i=1,100 do
		local x1,y1=to_render_coords(x+r*cos(i/100),y+r*sin(i/100),z)
		pset(x1,y1,c)
	end
end

function rect_perspective(x1,y1,x2,y2,c)
	local px1,py1=to_render_coords(x1,y1)
	local px2,py2=to_render_coords(x1,y2)
	local px3,py3=to_render_coords(x2,y2)
	local px4,py4=to_render_coords(x2,y1)
	line(px1,py1,px2,py2,c)
	line(px2,py2,px3,py3,c)
	line(px3,py3,px4,py4,c)
	line(px4,py4,px1,py1,c)
end
