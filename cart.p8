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
		radius=5,
		check_collision=true,
		update=function(self)
			-- check inputs
			self.move_x=ternary(buttons[1],1,0)-ternary(buttons[0],1,0)
			self.move_y=ternary(buttons[3],1,0)-ternary(buttons[2],1,0)
			-- adjust velocity
			self.vx=self.move_x -- *ternary(self.move_y==0,1,0.7)
			self.vy=self.move_y -- *ternary(self.move_x==0,1,0.7)
		end,
		draw=function(self)
			circfill(self.x+0.5,self.y+0.5,self.radius,8)
		end
	},
	passenger={
		radius=5,
		is_obstacle=true,
		draw=function(self)
			circfill(self.x+0.5,self.y+0.5,self.radius,1)
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
					local dx=entity2.x-entity1.x
					local dy=entity2.y-entity1.y
					local square_dist=dx*dx+dy*dy
					local sum_radius=entity1.radius+entity2.radius
					-- the entities are overlapping
					if square_dist<sum_radius*sum_radius then
						local dist=sqrt(square_dist)
						local dist_to_nudge=sum_radius-dist
						entity1.x-=dist_to_nudge*dx/dist
						entity1.y-=dist_to_nudge*dy/dist
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
	camera(-4,-29)
	rectfill(0,0,120,70,15)
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
			radius=0,
			-- entity methods
			init=noop,
			update=noop,
			post_update=noop,
			draw=noop,
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
