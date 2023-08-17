extends Node2D

@export var change_generation_method=1
@export var level_size = Vector2(150, 150)
@export var rooms_size = Vector2(15, 25)
@export var rooms_max = 10
@export var corridor_size=3
var data={}
var enemies={}
var rooms={}
var sweeped_rooms={}
var dors=[]
var rendering_mode="standart"
@onready var level: TileMap = $Level

func _generate():
	var regenerate=true
	var rng = RandomNumberGenerator.new()
	while regenerate:
		for room in enemies:
			for enemy in enemies.get(room):
				enemy.queue_free()
		$Player.position=Vector2(0,0)
		level.clear()
		data={}
		enemies={}
		for room in rooms:
			remove_child(room)
		rooms = {}
		sweeped_rooms={}
		dors=[]
		regenerate=_generate_data(rng)
	_room_area_and_walls()
	await get_tree().physics_frame
	_add_connections(rng)
	await get_tree().physics_frame
	_add_dors()
	await get_tree().physics_frame
	_room_cells()
	
func _fill_level(room:Area2D):
	if rendering_mode=="standart":
		for point in data:
			if $Player.position.distance_squared_to(point*32)<470000:
				if level.get_cell_atlas_coords(0,point):
					if data.get(point)==1 or data.get(point)==2:
						level.set_cell(0,point,0,Vector2(12,4))
					elif data.get(Vector2(point))==3:
						if data.get(point+Vector2(0,1))!=3:
							level.set_cell(1,point+Vector2(0,1),0,Vector2(24,6))
						level.set_cell(0,point,0,Vector2(12,4))
					elif data.get(Vector2(point))==0:
						level.set_cell(0,point,0,Vector2(38,6))
			else:
				level.erase_cell(0,point)
				level.erase_cell(1,point)
	elif rendering_mode=="fight":
		level.clear()
		for point in rooms.get(room):
			if data.get(point) in [1,2,3]:
				level.set_cell(0,point,0,Vector2(12,4))
			elif data.get(Vector2(point))==0: 
				level.set_cell(0,point,0,Vector2(38,6))
	elif rendering_mode=="debug":
		for point in data:
			if data.get(point)==1 or data.get(point)==2:
				level.set_cell(0,point,0,Vector2(12,4))
			elif data.get(Vector2(point))==3:
				if data.get(point+Vector2(0,1))!=3:
					level.set_cell(1,point+Vector2(0,1),0,Vector2(24,6))
				level.set_cell(0,point,0,Vector2(12,4))
			elif data.get(Vector2(point))==0:
				level.set_cell(0,point,0,Vector2(38,6))

func _generate_data(rng:RandomNumberGenerator):
	rng.randomize()
	var room
	var tries_before_regeneration=20
	while rooms.size()<7 and rooms.size()<rooms_max:
		room = _get_random_room(rng)
		if room:
			tries_before_regeneration=20
			rooms[room[0]]=room[1]
			add_child(room[0])
			room[0].body_entered.connect(_player_enters_room)
			_add_creatures(rng,room[0])
		elif tries_before_regeneration<=0 and data.size()>7000:
			return true
		elif tries_before_regeneration<=-30:
			return true
		else:
			tries_before_regeneration-=1
		print(snapped(rooms.size()/7.0,0.1))
	return false

func _get_random_room(rng: RandomNumberGenerator) :
	var area=Area2D.new()
	var col=CollisionShape2D.new()
	area.add_child(col)
	var shape
	var posx:int
	var posy:int
	var c=32
	var room_dic={}
	if rng.randi_range(0,1):
		var y:int
		var radius=rng.randi_range(rooms_size.x,rooms_size.y)*1.3
		posx = rng.randi_range(2+radius, level_size.x - radius - 2)
		posy = rng.randi_range(2+radius, level_size.y - radius - 2)
		shape=CircleShape2D.new()
		shape.set_radius(radius*c)
		for xi in range(-radius,radius+1):
			y=round(sqrt(-xi*xi+radius*radius))
			for yi in range(-y,y):
				if !data.has(Vector2(xi+posx,yi+posy)):
					room_dic[Vector2(xi+posx,yi+posy)]=1
				else:
					area.queue_free()
					return null
	else:
		var width = rng.randi_range(rooms_size.x, rooms_size.y)
		var height =rng.randi_range(rooms_size.x, rooms_size.y)
		posx = rng.randi_range(2+width, level_size.x - width - 2)
		posy = rng.randi_range(2+height, level_size.y - height - 2)
		shape=RectangleShape2D.new()
		shape.set_size(Vector2(width,height)*2*c)
		for xi in range(posx-width, posx+width):
			for yi in range(posy-height, posy+height):
				if !data.has(Vector2(xi, yi)):
					room_dic[Vector2(xi, yi)] = 1
				else:
					area.queue_free()
					return null
	area.set_collision_mask_value(10,true)
	col.set_shape(shape)
	area.position=Vector2(posx,posy)*c
	data.merge(room_dic)
	var r=[area,room_dic.keys()]
	return r

func _room_area_and_walls():
	for room in rooms:
		if room.get_child(0).get_shape().get_class()=="CircleShape2D":
			var radius=room.get_child(0).get_shape().get_radius()/32
			room.get_child(0).get_shape().set_radius((radius-2.5)*32)
		elif room.get_child(0).get_shape().get_class()=="RectangleShape2D":
			var width=room.get_child(0).get_shape().get_size().x/64
			var height=room.get_child(0).get_shape().get_size().y/64
			room.get_child(0).get_shape().set_size(Vector2(width-2,height-2)*64)
		for point in rooms.get(room):
			if !rooms.get(room).has(point+Vector2(-1,0)):
				data[point]=0
				continue
			if !rooms.get(room).has(point+Vector2(-1,-1)):
				data[point]=0
				continue
			if !rooms.get(room).has(point+Vector2(0,-1)):
				data[point]=0
				continue
			if !rooms.get(room).has(point+Vector2(1,-1)):
				data[point]=0
				continue
			if !rooms.get(room).has(point+Vector2(1,0)):
				data[point]=0
				continue
			if !rooms.get(room).has(point+Vector2(1,1)):
				data[point]=0
				continue
			if !rooms.get(room).has(point+Vector2(0,1)):
				data[point]=0
				continue
			if !rooms.get(room).has(point+Vector2(-1,1)):
				data[point]=0
				continue
		
	print("2")

func _room_cells():
	for room in rooms:
		for point in rooms.get(room):
			if data.get(point)==1:
				var corridor_cells=[point]
				var index=0
				var point_count=1
				while index<point_count:
					point=corridor_cells[index]
					if (data.get(point+Vector2(-1,0))==2 or
						data.get(point+Vector2(-1,0))==3 or
						data.get(point+Vector2(-1,0))==1 and 
						!rooms.get(room).has(point+Vector2(-1,0)) ) and !corridor_cells.has(point+Vector2(-1,0)):
							corridor_cells.push_back(point+Vector2(-1,0))
							rooms.get(room).push_back(point+Vector2(-1,0))
							point_count+=1
					elif data.get(point+Vector2(-1,0))==0:
						if !rooms.get(room).has(point+Vector2(-1,0)):
							rooms.get(room).push_back(point+Vector2(-1,0))
					if (data.get(point+Vector2(-1,-1))==2 or
						data.get(point+Vector2(-1,-1))==3 or
						data.get(point+Vector2(-1,-1))==1 and 
						!rooms.get(room).has(point+Vector2(-1,-1)) ) and !corridor_cells.has(point+Vector2(-1,-1)):
							corridor_cells.push_back(point+Vector2(-1,-1))
							rooms.get(room).push_back(point+Vector2(-1,-1))
							point_count+=1
					elif data.get(point+Vector2(-1,-1))==3 or data.get(point+Vector2(-1,-1))==0:
						if !rooms.get(room).has(point+Vector2(-1,-1)):
							rooms.get(room).push_back(point+Vector2(-1,-1))
					if (data.get(point+Vector2(0,-1))==2 or
						data.get(point+Vector2(0,-1))==3 or
						data.get(point+Vector2(0,-1))==1 and 
						!rooms.get(room).has(point+Vector2(0,-1)) ) and !corridor_cells.has(point+Vector2(0,-1)):
							corridor_cells.push_back(point+Vector2(0,-1))
							rooms.get(room).push_back(point+Vector2(0,-1))
							point_count+=1
					elif data.get(point+Vector2(0,-1))==3 or data.get(point+Vector2(0,-1))==0:
						if !rooms.get(room).has(point+Vector2(0,-1)):
							rooms.get(room).push_back(point+Vector2(0,-1))
					if (data.get(point+Vector2(1,-1))==2 or
						data.get(point+Vector2(1,-1))==3 or
						data.get(point+Vector2(1,-1))==1 and 
						!rooms.get(room).has(point+Vector2(1,-1)) ) and !corridor_cells.has(point+Vector2(1,-1)):
							corridor_cells.push_back(point+Vector2(1,-1))
							rooms.get(room).push_back(point+Vector2(1,-1))
							point_count+=1
					elif data.get(point+Vector2(1,-1))==3 or data.get(point+Vector2(1,-1))==0:
						if !rooms.get(room).has(point+Vector2(1,-1)):
							rooms.get(room).push_back(point+Vector2(1,-1))
					if (data.get(point+Vector2(1,0))==2 or
						data.get(point+Vector2(1,0))==3 or
						data.get(point+Vector2(1,0))==1 and 
						!rooms.get(room).has(point+Vector2(1,0)) ) and !corridor_cells.has(point+Vector2(1,0)):
							corridor_cells.push_back(point+Vector2(1,0))
							rooms.get(room).push_back(point+Vector2(1,0))
							point_count+=1
					elif data.get(point+Vector2(1,0))==3 or data.get(point+Vector2(1,0))==0:
						if !rooms.get(room).has(point+Vector2(1,0)):
							rooms.get(room).push_back(point+Vector2(1,0))
					if (data.get(point+Vector2(1,1))==2 or
						data.get(point+Vector2(1,1))==3 or
						data.get(point+Vector2(1,1))==1 and 
						!rooms.get(room).has(point+Vector2(1,1)) ) and !corridor_cells.has(point+Vector2(1,1)):
							corridor_cells.push_back(point+Vector2(1,1))
							rooms.get(room).push_back(point+Vector2(1,1))
							point_count+=1
					elif data.get(point+Vector2(1,1))==3 or data.get(point+Vector2(1,1))==0:
						if !rooms.get(room).has(point+Vector2(1,1)):
							rooms.get(room).push_back(point+Vector2(1,1))
					if (data.get(point+Vector2(0,1))==2 or
						data.get(point+Vector2(0,1))==3 or
						data.get(point+Vector2(0,1))==1 and 
						!rooms.get(room).has(point+Vector2(0,1)) ) and !corridor_cells.has(point+Vector2(0,1)):
							corridor_cells.push_back(point+Vector2(0,1))
							rooms.get(room).push_back(point+Vector2(0,1))
							point_count+=1
					elif data.get(point+Vector2(0,1))==3 or data.get(point+Vector2(0,1))==0:
						if !rooms.get(room).has(point+Vector2(0,1)):
							rooms.get(room).push_back(point+Vector2(0,1))
					if (data.get(point+Vector2(-1,1))==2 or
						data.get(point+Vector2(-1,1))==3 or
						data.get(point+Vector2(-1,1))==1 and 
						!rooms.get(room).has(point+Vector2(-1,1)) ) and !corridor_cells.has(point+Vector2(-1,1)):
							corridor_cells.push_back(point+Vector2(-1,1))
							rooms.get(room).push_back(point+Vector2(-1,1))
							point_count+=1
					elif data.get(point+Vector2(-1,1))==3 or data.get(point+Vector2(-1,1))==0:
						if !rooms.get(room).has(point+Vector2(-1,1)):
							rooms.get(room).push_back(point+Vector2(-1,1))
					index+=1
	print("6")


func _add_dors():
	var all_dors={}
	_add_all_dors(all_dors)
	print("4")
	_choose_best_dors(all_dors)
	print("5")

func _add_all_dors(all_dors:Dictionary):
	for x in level_size.x:
		for y in level_size.y:
			if data.get(Vector2(x,y))==2:
				var maybedor=[]
				var hororver#dor is horizontal or vertical
				if data.get(Vector2(x-1,y))==0:
					for cell in range(corridor_size*2+1):
						if data.get(Vector2(x+cell,y))==2 and cell>=corridor_size*2:
							maybedor=[]
						elif data.get(Vector2(x+cell,y))==2:
							maybedor.push_back(Vector2(x+cell,y))
						elif data.get(Vector2(x+cell,y))==0:
							break
						else:
							maybedor=[]
							break
						hororver=0
				elif data.get(Vector2(x,y-1))==0:
					for cell in range(corridor_size*2+1):
						if data.get(Vector2(x,y+cell))==2 and cell>=corridor_size*2:
							maybedor=[]
						elif data.get(Vector2(x,y+cell))==2:
							maybedor.push_back(Vector2(x,y+cell))
						elif data.get(Vector2(x,y+cell))==0:
							break
						else:
							maybedor=[]
							break
						hororver=1
				elif data.get(Vector2(x+1,y))==0:
					for cell in range(corridor_size*2+1):
						if data.get(Vector2(x-cell,y))==2 and cell>=corridor_size*2:
							maybedor=[]
						elif data.get(Vector2(x-cell,y))==2:
							maybedor.push_back(Vector2(x-cell,y))
						elif data.get(Vector2(x-cell,y))==0:
							break
						else:
							maybedor=[]
							break
						hororver=0
				elif data.get(Vector2(x,y+1))==0:
					for cell in range(corridor_size*2+1):
						if data.get(Vector2(x,y-cell))==2 and cell>=corridor_size*2:
							maybedor=[]
						elif data.get(Vector2(x,y-cell))==2:
							maybedor.push_back(Vector2(x,y-cell))
						elif data.get(Vector2(x,y-cell))==0:
							break
						else:
							maybedor=[]
							break
						hororver=1
				if maybedor:
					var linedor=Line2D.new()
					for point in maybedor:
						data[point]=3
						linedor.add_point(point)
					all_dors[linedor]=hororver

func _choose_best_dors(all_dors:Dictionary):
	for dor in all_dors:
		var point =dor.get_point_position(0)
		var near_cells=[point]
		var index=0
		var point_count=1
		var is_way_to_room=false
		while index<point_count:
			point=near_cells[index]
			if data.get(point-Vector2(1,0))==2 and !near_cells.has(point-Vector2(1,0)):
				near_cells.push_back(point-Vector2(1,0))
				point_count+=1
			elif data.get(point-Vector2(1,0))==1:
				is_way_to_room=true 
				break
				
			if data.get(point-Vector2(0,1))==2 and !near_cells.has(point-Vector2(0,1)):
				near_cells.push_back(point-Vector2(0,1))
				point_count+=1
			elif data.get(point-Vector2(0,1))==1:
				is_way_to_room=true
				break
				
			if data.get(point+Vector2(1,0))==2 and !near_cells.has(point+Vector2(1,0)):
				near_cells.push_back(point+Vector2(1,0))
				point_count+=1
			elif data.get(point+Vector2(1,0))==1:
				is_way_to_room=true
				break
				
			if data.get(point+Vector2(0,1))==2 and !near_cells.has(point+Vector2(0,1)):
				near_cells.push_back(point+Vector2(0,1))
				point_count+=1
			elif data.get(point+Vector2(0,1))==1:
				is_way_to_room=true
				break
				
			index+=1
		if !is_way_to_room:
			for pt in dor.get_point_count():
				data[dor.get_point_position(pt)]=2
		else:
			dors.push_back(dor)
		#Another way to identify dors
		#var cell=0
		#var twosides=0
		#var x=dor.get_point_position(round(dor.get_point_count()/2)).x
		#var y=dor.get_point_position(round(dor.get_point_count()/2)).y
		#if all_dors[dor]:
		#	while twosides<3:
		#		cell+=1
		#		if data.get(Vector2(x-cell,y))==1 and twosides%2==0:
		#			break
		#		elif data.get(Vector2(x-cell,y))!=2 and twosides%2==0:
		#			twosides+=1
		#		if data.get(Vector2(x+cell,y))==1 and twosides<=1:
		#			break
		#		elif data.get(Vector2(x+cell,y))!=2 and twosides<=1:
		#			twosides+=2
		#else:
		#	while twosides<3:
		#		cell+=1
		#		if data.get(Vector2(x,y-cell))==1 and twosides%2==0:
		#			break
		#		elif data.get(Vector2(x,y-cell))!=2 and twosides%2==0:
		#			twosides+=1
		#		if data.get(Vector2(x,y+cell))==1 and twosides<=1:
		#			break
		#		elif data.get(Vector2(x,y+cell))!=2 and twosides<=1:
		#			twosides+=2
		#if twosides>=3:
		#	for pt in dor.get_point_count():
		#		data[dor.get_point_position(pt)]=2
		#else:
		#	dors.push_back(dor)
	all_dors.clear()

func _change_dors_mode(Open:bool,room):
	for point in rooms.get(room):
		if data.get(point)==3:
			if Open:
				if data.get(point-Vector2(0,1))!=3:
					level.erase_cell(1,point-Vector2(0,1))
				if data.get(point+Vector2(0,1))!=3:
					level.set_cell(1,point+Vector2(0,1),0,Vector2(24,6))
				level.set_cell(0,point,0,Vector2(12,4))
				level.erase_cell(1,point)
			else:
				if data.get(point-Vector2(0,1))!=3:
					level.set_cell(1,point-Vector2(0,1),0,Vector2(46,6))
				if data.get(point+Vector2(0,1))!=3:
					level.set_cell(1,point+Vector2(0,1),0,Vector2(50,4))
				level.set_cell(1,point,0,Vector2(30,4))


func _add_creatures(rng:RandomNumberGenerator, room:Area2D):
	if $Player.position!=Vector2(0,0):
		var room_monsters=[]
		for en in rng.randi_range(1,2):
			var child_enemy=get_node("Red_monster").duplicate()			
			room_monsters.push_back(child_enemy)
			add_child(child_enemy)
			child_enemy.position=room.position+Vector2(rng.randi_range(-150,150),rng.randi_range(-150,150))
			child_enemy.visible=true
			child_enemy.room=room
		enemies[room]=room_monsters
	else:
		sweeped_rooms[room]=true
		$Player.position=room.position

func _add_connections(rng: RandomNumberGenerator):
	var used_rooms=[]
	for room in rooms:
		if !used_rooms.has(room):
			used_rooms.push_back(room)
		var distace=9999999
		var nearest_room:Area2D
		for room2 in rooms:
			if distace>(room.position/32).distance_squared_to(room2.position/32) and !used_rooms.has(room2):
				distace=(room.position/32).distance_squared_to(room2.position/32)
				nearest_room=room2
		if nearest_room:
			var room_center1 = room.position/32
			var room_center2 = nearest_room.position/32
			if !rng.randi_range(0, 1):
				_add_corridor(room_center1.x, room_center2.x, room_center1.y, Vector2.AXIS_X)#Exit horizontal
				_add_corridor(room_center1.y, room_center2.y, room_center2.x, Vector2.AXIS_Y)#Enter vertical
			else:
				_add_corridor(room_center1.y, room_center2.y, room_center1.x, Vector2.AXIS_Y)#Exit vertical
				_add_corridor(room_center1.x, room_center2.x, room_center2.y, Vector2.AXIS_X)#Enter horizontal
	print("3")
	_add_walls_for_corridors()
	print("3.5")

func _add_corridor( start: int, end: int, constant: int, axis: int) :
	for cor_length in corridor_size+2:
		for t in range(min(start, end), max(start, end) + cor_length+1):
			var point = Vector2.ZERO
			match axis:
				Vector2.AXIS_X: point = Vector2(t, constant+cor_length)
				Vector2.AXIS_Y: point = Vector2(constant+cor_length, t)
			if data.get(point)!=1:
				if cor_length>0 and cor_length<corridor_size+1:
					data[point] = 2
				elif  data.get(point)==null:
					data[point]=0

func _add_walls_for_corridors():
	for point in data:
		if data.get(point)==2:
			if data.get(point+Vector2(-1,0))==null:
				data[point]=0
				continue
			if data.get(point+Vector2(-1,-1))==null:
				data[point]=0
				continue
			if data.get(point+Vector2(0,-1))==null:
				data[point]=0
				continue
			if data.get(point+Vector2(1,-1))==null:
				data[point]=0
				continue
			if data.get(point+Vector2(1,0))==null:
				data[point]=0
				continue
			if data.get(point+Vector2(1,1))==null:
				data[point]=0
				continue
			if data.get(point+Vector2(0,1))==null:
				data[point]=0
				continue
			if data.get(point+Vector2(-1,1))==null:
				data[point]=0
				continue

func _player_enters_room(_body:Node2D):
	pass
func find_nearest_room(player):
	for room in rooms:
		if rooms.get(room).has(Vector2(level.local_to_map(player))):
			return room
