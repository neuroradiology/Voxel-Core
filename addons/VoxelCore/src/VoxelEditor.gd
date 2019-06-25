tool
extends Spatial
class_name VoxelEditor, 'res://addons/VoxelCore/assets/VoxelEditor.png'



# Declarations
var undo_redo : UndoRedo = UndoRedo.new()

var OriginalBuildGreedy : bool = false setget set_original_build_greedy
func set_original_build_greedy(build_greedy : bool) -> void:
	OriginalBuildGreedy = build_greedy

signal begined
var VoxelObjectRef : VoxelObject setget begin
# Clears previous VoxelObjectRef, then sets given VoxelObject as VoxelObjectRef and 'edits' accordingly
# voxelobject   :   VoxelObject   -   VoxelObject to be 'edited'
# edit          :   bool          -   true, begin editing immediately; false, prevents from editing immediately
# emit          :   bool          -   true, emit 'begined' signal; false, don't emit 'begined' signal
#
# Example:
#   begin([VoxelObject], true, false)
#
func begin(voxelobject : VoxelObject, edit : bool = false, emit : bool = true) -> void:
	clear(emit)
	
	VoxelObjectRef = voxelobject
	
	set_original_build_greedy(VoxelObjectRef.BuildGreedy)
	VoxelObjectRef.connect('set_buildgreedy', self, 'set_original_build_greedy')
	
	set_edit(edit, false)
	set_edit_lock(VoxelObjectRef.Lock, emit)
	VoxelObjectRef.connect('set_lock', self, 'set_edit_lock')
	
	set_mirror_x_lock(VoxelObjectRef.Mirror_X, emit)
	VoxelObjectRef.connect('set_mirror_x', self, 'set_mirror_x_lock')
	set_mirror_y_lock(VoxelObjectRef.Mirror_Y, emit)
	VoxelObjectRef.connect('set_mirror_y', self, 'set_mirror_y_lock')
	set_mirror_z_lock(VoxelObjectRef.Mirror_Z, emit)
	VoxelObjectRef.connect('set_mirror_z', self, 'set_mirror_z_lock')
	
	set_floor_dimensions(VoxelObjectRef.Dimensions, emit)
	VoxelObjectRef.connect('set_dimensions', self, 'set_floor_dimensions')
	set_floor_visible(VoxelObjectRef.Voxels.size() == 0, emit)
	
	VoxelObjectRef.connect('update', VoxelObjectRef, 'update_body', [true])
	
	VoxelObjectRef.connect('tree_exiting', self, 'clear')
	
	VoxelObjectRef.update(true, emit)
	
	for cursor in Cursors:
		cursor.visible = false
		VoxelObjectRef.add_child(cursor)
	VoxelObjectRef.add_child(Floor)
	
	if emit: emit_signal('begined')

signal commited
# Apply Voxels given to VoxelObjectRef; and clears VoxelObjectRef
# voxels   :   Dictionary   -   array of voxels to update VoxelObjectRef with
# emit     :   bool         -   true, emit 'commited' signal; false, don't emit 'commited' signal
#
# Example:
#   commit({ ... }, false)
#
func commit(voxels = null, emit : bool = true) -> void:
	if typeof(voxels) == TYPE_DICTIONARY:
		VoxelObjectRef.set_voxels(voxels, false)
	
	clear(emit)
	set_edit(false, emit)
	
	if emit: emit_signal('commited')

signal cleared
# Clears VoxelObjectRef
# emit   :   bool    -   true, emit 'cleared' signal; false, don't emit 'cleared' signal
#
# Example:
#   clear()
#
func clear(emit : bool = true) -> void:
	if VoxelObjectRef != null:
		VoxelObjectRef.BuildGreedy = OriginalBuildGreedy
		OriginalBuildGreedy = false
		
		VoxelObjectRef.disconnect('set_buildgreedy', self, 'set_original_build_greedy')
		
		VoxelObjectRef.disconnect('set_lock', self, 'set_edit_lock')
		
		VoxelObjectRef.disconnect('set_mirror_x', self, 'set_mirror_x_lock')
		VoxelObjectRef.disconnect('set_mirror_y', self, 'set_mirror_y_lock')
		VoxelObjectRef.disconnect('set_mirror_z', self, 'set_mirror_z_lock')
		
		VoxelObjectRef.disconnect('set_dimensions', self, 'set_floor_dimensions')
		
		VoxelObjectRef.disconnect('update', VoxelObjectRef, 'update_body')
		
		VoxelObjectRef.disconnect('tree_exiting', self, 'clear')
		
		VoxelObjectRef.remove_child(Floor)
		for cursor in Cursors: VoxelObjectRef.remove_child(cursor)
		
		VoxelObjectRef.update()
		
		VoxelObjectRef = null
	
	if emit: emit_signal('cleared')


# TODO select, fill and bucket tool
enum Tools {ADD, REMOVE, PAINT, COLOR_PICKER}
signal set_tool(_tool)
# Operation being done when 'editing'
export var Tool = Tools.ADD setget set_tool
# Setter for Tool
# _tool   :   int[Tools]   -   tool to set current Tool to; Note: Use Tools to retrive value!
# emit    :   bool         -   true, emit 'set_tool' signal; false, don't emit 'set_tool' signal
#
# Example:
#   set_tool(Tools.ADD, false)
#
func set_tool(_tool : int, emit : bool = true) -> void:
	Tool = _tool
	
	if emit: emit_signal('set_tool', _tool)


signal set_edit(editing)
# Whether VoxelEditor is 'editing'
export var Edit : bool = true setget set_edit
# Setter for Edit
# edit   :   bool   -   true, editing; false, not editing
# emit   :   bool   -   true, emit 'set_edit' signal; false, don't emit 'set_edit' signal
#
# Example:
#   set_edit(false, false)
#
func set_edit(edit : bool = !Edit, emit : bool = true) -> void:
	if EditLock: edit = false
	
	Edit = edit
	
	if VoxelObjectRef:
		VoxelObjectRef.set_buildgreedy(false if edit else OriginalBuildGreedy, false, false)
		VoxelObjectRef.update(true)
	
	if emit: emit_signal('set_edit', edit)

signal set_edit_lock(locked)
# Whether VoxelEditor is able to edit
export var EditLock : bool = false setget set_edit_lock
# Setter for EditLock
# lock   :   bool   -   true, able to edit; false, unable to edit
# emit   :   bool   -   true, emit 'set_edit_lock' signal; false, don't emit 'set_edit_lock' signal
#
# Example:
#   set_edit_lock(false, false)
#
func set_edit_lock(lock : bool = true, emit : bool = true) -> void:
	EditLock = lock
	
	set_edit(Edit, emit)
	
	if emit: emit_signal('set_edit_lock', lock)


signal set_working_voxel(voxel)
# Voxel being used in 'editing' operations; if null then a new voxel is created with paint color
var WorkingVoxel = null setget set_working_voxel
# Setter for WorkingVoxel
# voxel   :   int/Dictionary   -   voxel to set as WorkingVoxel
# emit    :   bool             -   true, emit 'set_working_voxel' signal; false, don't emit 'set_working_voxel' signal
#
# Example:
#   set_working_voxel([Voxel], false)
#
func set_working_voxel(voxel, emit : bool = true) -> void:
	WorkingVoxel = voxel if typeof(voxel) == TYPE_INT or typeof(voxel) == TYPE_DICTIONARY else null
	
	if emit: emit_signal('set_working_voxel', WorkingVoxel)

signal set_paint_color(color)
# Color used in 'editing' operations
export var PaintColor : Color = Color(1, 1, 1, 1) setget set_paint_color
# Setter for PaintColor
# color   :   Color   -   Color to set PaintColor
# emit    :   bool    -   true, emit 'set_paint_color' signal; false, don't emit 'set_paint_color' signal
#
# Example:
#   set_paint_color(Color(1, 0, 0.33), false)
#
func set_paint_color(color : Color, emit : bool = true) -> void:
	PaintColor = color
	
	if emit: emit_signal('set_paint_color', color)


signal set_mirror_x(mirroring)
# Whether operations are mirrored over x planes
export var Mirror_X : bool setget set_mirror_x
# Setter for Mirror_X
# mirror   :   bool   -   value to set Mirror_X
# emit     :   bool   -   true, emit 'set_mirror_x' signal; false, don't emit 'set_mirror_x' signal
#
# Example:
#   set_mirror_x(false false)
#
func set_mirror_x(mirror : bool = !Mirror_X, emit : bool = true) -> void:
	if Mirror_X_Lock: mirror = true
	
	Mirror_X = mirror
	
	if emit: emit_signal('set_mirror_x', mirror)

signal set_mirror_x_lock(locked)
# Whether mirroring operations over x planes are allowed
var Mirror_X_Lock : bool = false setget set_mirror_x_lock
# Setter for Mirror_X_Lock
# lock   :   bool   -   value to set Mirror_X_Lock
# emit   :   bool   -   true, emit 'set_mirror_x_lock' signal; false, don't emit 'set_mirror_x_lock' signal
#
# Example:
#   set_mirror_x_lock(false false)
#
func set_mirror_x_lock(lock : bool = !Mirror_X_Lock, emit : bool = true) -> void:
	Mirror_X_Lock = lock
	
	set_mirror_x(lock)
	
	if emit: emit_signal('set_mirror_x_lock', lock)

signal set_mirror_y(mirroring)
# Whether operations are mirrored over y planes
export var Mirror_Y : bool setget set_mirror_y
# Setter for Mirror_Y
# mirror   :   bool   -   value to set Mirror_Y
# emit     :   bool   -   true, emit 'set_mirror_y' signal; false, don't emit 'set_mirror_y' signal
#
# Example:
#   set_mirror_y(false false)
#
func set_mirror_y(mirror : bool = !Mirror_Y, emit : bool = true) -> void:
	if Mirror_Y_Lock: mirror = true
	
	Mirror_Y = mirror
	
	if emit: emit_signal('set_mirror_y', mirror)

signal set_mirror_y_lock(locked)
# Whether mirroring operations over y planes are allowed
var Mirror_Y_Lock : bool = false setget set_mirror_y_lock
# Setter for Mirror_Y_Lock
# lock   :   bool   -   value to set Mirror_Y_Lock
# emit   :   bool   -   true, emit 'set_mirror_y' signal; false, don't emit 'set_mirror_y' signal
#
# Example:
#   set_mirror_y(false false)
#
func set_mirror_y_lock(lock : bool = !Mirror_Y_Lock, emit : bool = true) -> void:
	Mirror_Y_Lock = lock
	
	set_mirror_y(lock)
	
	if emit: emit_signal('set_mirror_y_lock', lock)

signal set_mirror_z(mirroring)
# Whether operations are mirrored over z planes
export var Mirror_Z : bool setget set_mirror_z
# Setter for Mirror_Z
# mirror   :   bool   -   value to set Mirror_Z
# emit     :   bool   -   true, emit 'set_mirror_z' signal; false, don't emit 'set_mirror_z' signal
#
# Example:
#   set_mirror_z(false false)
#
func set_mirror_z(mirror : bool = !Mirror_Z, emit : bool = true) -> void:
	if Mirror_Z_Lock: mirror = true
	
	Mirror_Z = mirror
	
	if emit: emit_signal('set_mirror_z', mirror)

signal set_mirror_z_lock(locked)
# Whether mirroring operations over z planes are allowed
var Mirror_Z_Lock : bool = false setget set_mirror_z_lock
# Setter for Mirror_Z_Lock
# lock   :   bool   -   value to set Mirror_Z_Lock
# emit   :   bool   -   true, emit 'set_mirror_z_lock' signal; false, don't emit 'set_mirror_z_lock' signal
#
# Example:
#   set_mirror_z_lock(false false)
#
func set_mirror_z_lock(lock : bool = !Mirror_Z_Lock, emit : bool = true) -> void:
	Mirror_Z_Lock = lock
	
	set_mirror_z(lock)
	
	if emit: emit_signal('set_mirror_z_lock', lock)


# Contains a refrence to each Cursor
var Cursors : Array = [
	MeshInstance.new(),
	MeshInstance.new(),
	MeshInstance.new(),
	MeshInstance.new(),
	MeshInstance.new(),
	MeshInstance.new(),
	MeshInstance.new(),
	MeshInstance.new()
] setget set_cursors
# Cursor references should not be modifiable
func set_cursors(cursors) -> void:
	return

signal set_cursor_visible(visible)
# Visibility of Cursors
export var CursorVisible : bool = true setget set_cursor_visible
# Setter for CursorVisible
# visible   :   bool   -   value to set CursorVisible
# emit      :   bool   -   true, emit 'set_cursor_visible' signal; false, don't emit 'set_cursor_visible' signal
#
# Example:
#   set_cursor_visible(false false)
#
func set_cursor_visible(visible : bool = !CursorVisible, emit : bool = true) -> void:
	CursorVisible = visible
	
	for cursor in Cursors:
		cursor.visible = CursorVisible
	
	if emit: emit_signal('set_cursor_visible', visible)

signal set_cursor_color(color)
# Color for Cursors
export var CursorColor : Color = Color(1, 0, 0, 0.6) setget set_cursor_color
# Setter for CursorColor
# color   :   color   -   value to set CursorColor, and each Cursor
# emit    :   bool    -   true, emit 'set_cursor_color' signal; false, don't emit 'set_cursor_color' signal
#
# Example:
#   set_cursor_color(Color(0.5, 0.03, 0.6, 0.3), false)
#
func set_cursor_color(color : Color, emit : bool = true) -> void:
	CursorColor = color
	
	for cursor in Cursors:
		if cursor.material_override && cursor.material_override.albedo_color:
			cursor.material_override.albedo_color = CursorColor
	
	if emit: emit_signal('set_cursor_color', color)

# Refrence to Floor
var Floor : MeshInstance = MeshInstance.new() setget set_floor
# Floor references should not be modifiable
func set_floor(_floor) -> void:
	return

signal set_floor_solid(floorsolid)
# Floor's appearance state; true, floor is visibly solid; false, floor is a grid
export var FloorSolid : bool = false setget set_floor_solid
# Setter for FloorSolid
# solid   :   bool   -   value to set FloorSolid
# emit    :   bool   -   true, emit 'set_floor_solid' signal; false, don't emit 'set_floor_solid' signal
#
# Example:
#   set_floor_solid(false false)
#
func set_floor_solid(solid : bool = !FloorSolid, emit : bool = true):
	FloorSolid = solid
	
	update_floor(VoxelObjectRef.Dimensions if VoxelObjectRef else Vector3.ONE)
	
	if emit: emit_signal('set_floor_solid', solid)

signal set_floor_visible(visible)
# Visibility of Floor
export var FloorVisible : bool = true setget set_floor_visible
# Setter for FloorVisible
# visible   :   bool   -   value to set FloorVisible
# emit      :   bool   -   true, emit 'set_floor_visible' signal; false, don't emit 'set_floor_visible' signal
#
# Example:
#   set_floor_visible(false false)
#
func set_floor_visible(visible : bool = (!Floor.visible if Floor != null else true), emit : bool = true) -> void:
	if FloorConstant: visible = true
	
	FloorVisible = visible
	
	Floor.visible = visible
	if Floor.has_node('VEFloor_col'): Floor.get_node('VEFloor_col').get_children()[0].disabled = !FloorVisible
	
	if emit: emit_signal('set_floor_visible', visible)

signal set_floor_constant(constant)
# Whether Floor is visible regardless of context (e.g. present voxels)
export var FloorConstant : bool = false setget set_floor_constant
# Setter for FloorConstant
# visible   :   bool   -   value to set FloorConstant
# emit      :   bool   -   true, emit 'set_floor_constant' signal; false, don't emit 'set_floor_constant' signal
#
# Example:
#   set_floor_constant(false false)
#
func set_floor_constant(constant : bool = !FloorConstant, emit : bool = true) -> void:
	FloorConstant = constant
	
	set_floor_visible(VoxelObjectRef and VoxelObjectRef.Voxels.size() == 0)
#	if VoxelObjectRef and VoxelObjectRef.Voxels.size() > 0:
#		set_floor_visible(false)
#	else:
#		set_floor_visible(true)
	
	if emit: emit_signal('set_floor_constant', constant)

signal set_floor_color(color)
# Color for Floor
export var FloorColor : Color = Color(0, 1, 0) setget set_floor_color
# Setter for FloorColor
# color   :   Color   -   value to set FloorColor
# emit    :   bool    -   true, emit 'set_floor_color' signal; false, don't emit 'set_floor_color' signal
#
# Example:
#   set_floor_color(Color(1, 0, 0.11, 0.33), false)
#
func set_floor_color(color : Color, emit : bool = true) -> void:
	FloorColor = color
	
	if Floor.material_override && Floor.material_override.albedo_color:
		Floor.material_override.albedo_color = color
	
	if emit: emit_signal('set_floor_color', color)

signal set_floor_dimensions(dimensions)
# Setter for Floor dimensions
# dimensions   :   Vector3   -   dimensions to set to Floor
# emit         :   bool      -   true, emit 'set_floor_dimensions' signal; false, don't emit 'set_floor_dimensions' signal
#
# Example:
#   set_floor_dimensions(Vector3(12, 12, 12), false)
#
func set_floor_dimensions(dimensions : Vector3, emit : bool = true) -> void:
	update_floor(dimensions)
	
	if emit: emit_signal('set_floor_dimensions', Floor.scale)

signal update_floor(dimensions)
# Updates the floor appearance
# dimensions   :   Vector3   -   dimensions to set to Floor
# emit         :   bool      -   true, emit 'update_floor' signal; false, don't emit 'update_floor' signal
#
# Example:
#   update_floor(Vector3(12, 12, 12), false)
#
func update_floor(dimensions : Vector3, emit : bool = true) -> void:
	for child in Floor.get_children():
		Floor.remove_child(child)
		child.queue_free()
	
	Floor.set_name('VEFloor')
	Floor.visible = FloorVisible
	
	if FloorSolid:
		Floor.mesh = PlaneMesh.new()
		Floor.scale = dimensions * Voxel.GridStep
		Floor.create_trimesh_collision()
		Floor.material_override = SpatialMaterial.new()
		Floor.material_override.set_cull_mode(2)
		Floor.material_override.albedo_color = FloorColor
	else:
		Floor.scale = Vector3.ONE
		
		var ST = SurfaceTool.new()
		ST.begin(Mesh.PRIMITIVE_LINES)
		ST.add_color(FloorColor)
		
		var material = SpatialMaterial.new()
		material.roughness = 1
		material.vertex_color_is_srgb = true
		material.vertex_color_use_as_albedo = true
		material.set_cull_mode(2)
		ST.set_material(material)
		
		var x : int = -dimensions.x
		while x <= dimensions.x:
			ST.add_normal(Vector3.UP)
			ST.add_vertex(Voxel.grid_to_pos(Vector3(x, 0, -abs(dimensions.z))))
			ST.add_vertex(Voxel.grid_to_pos(Vector3(x, 0, abs(dimensions.z))))
			
			x += 1
		
		var z : int = -dimensions.z
		while z <= dimensions.z:
			ST.add_normal(Vector3.UP)
			ST.add_vertex(Voxel.grid_to_pos(Vector3(-abs(dimensions.x), 0, z)))
			ST.add_vertex(Voxel.grid_to_pos(Vector3(abs(dimensions.x), 0, z)))
			
			z += 1
		
		ST.index()
		
		Floor.mesh = ST.commit()
		Floor.create_convex_collision()
	
	if Floor.has_node('VEFloor_col'): Floor.get_node('VEFloor_col').get_children()[0].disabled = !FloorVisible
	
	if emit: emit_signal('update_floor', dimensions)



# Util
# Helper function for easy Raycasting
# event      :   InputEventMouse       -   MouseEvent to Raycast for
# camera     :   Camera                -   Camera from which to Raycast
# @returns   :   Raycast[Dictionary]   -   Dictionary containing all Raycast info
#
# Example:
#   raycast([InputEventMouse], [Camera]) -> [Raycast]
#
func raycast(event : InputEventMouse, camera : Camera = get_viewport().get_camera()) -> Dictionary:
	var from = camera.project_ray_origin(event.position)
	var to = from + camera.project_ray_normal(event.position) * 1000
	return camera.get_world().direct_space_state.intersect_ray(from, to)

# Helper function for easy Raycasting to a VoxelObject
# event         :   InputEventMouse       -   MouseEvent to Raycast for
# camera        :   Camera                -   Camera from which to Raycast
# voxelobject   :   VoxelObject           -   VoxelObject to raycast for
# exclude       :   Array                 -   Collision shapes to exclude from raycast
# @returns      :   Raycast[Dictionary]   -   Dictionary containing all Raycast info
#
# Example:
#   raycast_for_voxelobject([InputEventMouse], [Camera], [VoxelObject], [ ... ]) -> [Raycast]
#
func raycast_for_voxelobject(event : InputEventMouse, camera : Camera = get_viewport().get_camera(), voxelobject = VoxelObjectRef, exclude : Array = []) -> Dictionary:
	var hit : Dictionary
	var from = camera.project_ray_origin(event.position)
	var to = from + camera.project_ray_normal(event.position) * 1000
	while true:
		hit = camera.get_world().direct_space_state.intersect_ray(from, to, exclude)
		if hit:
			if voxelobject.is_a_parent_of(hit.collider): break
			else: exclude.append(hit.collider)
		else: break
	
	return hit

# Helper function for getting mirrors
# grid       :   Vector3            -   Grid position to mirrr according to Mirror options
# @returns   :   Array[Vector3]     -   Array containing original position and all mirrored position
#
# Example:
#   grid_to_mirrors(Vector(3, 1, -3)) -> [ Vector(3, 1, -3), ... ]
#
func grid_to_mirrors(grid : Vector3) -> Array:
	var mirrors = [grid]
	
	if Mirror_X:
		mirrors.append(Vector3(grid.x, grid.y, (grid.z + 1) * -1))
		
		if Mirror_Z:
			mirrors.append(Vector3((grid.x + 1) * -1, grid.y, (grid.z + 1) * -1))
	
	if Mirror_Y:
		mirrors.append(Vector3(grid.x, (grid.y + 1) * -1, grid.z))
		
		if Mirror_X:
			mirrors.append(Vector3(grid.x, (grid.y + 1) * -1, (grid.z + 1) * -1))
		
		if Mirror_Z:
			mirrors.append(Vector3((grid.x + 1) * -1, (grid.y + 1) * -1, grid.z))
		
		if Mirror_X && Mirror_Z:
			mirrors.append(Vector3((grid.x + 1) * -1, (grid.y + 1) * -1, (grid.z + 1) * -1))
	
	if Mirror_Z:
		mirrors.append(Vector3((grid.x + 1) * -1, grid.y, grid.z))
		
		if Mirror_X:
			mirrors.append(Vector3((grid.x + 1) * -1, grid.y, (grid.z + 1) * -1))
	
	return mirrors



# Core
func _init() -> void:
	for cursor in Cursors:
		cursor.set_name('VECursor')
		cursor.visible = CursorVisible
		cursor.mesh = CubeMesh.new()
		cursor.scale = Vector3(Voxel.VoxelSize, Voxel.VoxelSize, Voxel.VoxelSize)
		cursor.material_override = SpatialMaterial.new()
		cursor.material_override.flags_transparent = true
		cursor.material_override.albedo_color = CursorColor
	
	update_floor(Vector3.ONE)


# Handle a input event and does operations if needs be
# event      :   InputEvent    :   event to handle
# camera     :   Caemra        :   camera from which to handle event
# working    :   VoxelObject   :   VoxelObject on which operations should take place
# options    :   Dictionary    :   options for handling input
# @returns   :   bool          :   whether a operation has taken place
#
# Example:
#   handle_input([InputEvent], [Camera], [VoxelObject], { ... }) -> false
#
func handle_input(event : InputEvent, camera : Camera = get_viewport().get_camera(), working = VoxelObjectRef) -> bool:
	if Edit and VoxelObjectRef and event is InputEventMouse and !(event is InputEventMouseMotion and Input.is_mouse_button_pressed(BUTTON_RIGHT)):
		var hit = raycast_for_voxelobject(event, camera, working)
		if hit and working.is_a_parent_of(hit.collider):
			match Tool:
				Tools.REMOVE, Tools.PAINT, Tools.COLOR_PICKER:
					hit.normal *= 1 if hit.collider.get_parent().get_name() == 'VEFloor' else -1

			hit.position += hit.normal  * (Voxel.VoxelSize / 2)
			var mirrors = grid_to_mirrors(Voxel.clamp_grid(Voxel.abs_to_grid(working.to_local(hit.position)), VoxelObjectRef.Dimensions))

			if CursorVisible:
				for cursor in range(Cursors.size()):
					Cursors[cursor].visible = cursor < mirrors.size()
					if cursor < mirrors.size():
						Cursors[cursor].translation = Voxel.pos_correct(Voxel.grid_to_pos(mirrors[cursor]))

			# TODO multithreading?
			if event is InputEventMouseButton and event.pressed and event.button_index == BUTTON_LEFT:
				undo_redo.create_action('VoxelEditor ' + str(Tools.keys()[Tool]) + ' Operation')
				for mirror in mirrors:
					match Tool:
						Tools.ADD:
							undo_redo.add_do_method(working, 'set_voxel', mirror, Voxel.colored(PaintColor) if WorkingVoxel == null else WorkingVoxel)
							undo_redo.add_undo_method(working, 'erase_voxel', mirror)
						Tools.REMOVE:
							var voxel = working.Voxels.get(mirror)
							if voxel:
								undo_redo.add_do_method(working, 'erase_voxel', mirror)
								undo_redo.add_undo_method(working, 'set_voxel', mirror, voxel)
						Tools.PAINT:
							var voxel = working.Voxels.get(mirror)
							if voxel:
								var new_voxel = voxel.duplicate(true)
								Voxel.set_color(new_voxel, PaintColor)
								
								undo_redo.add_do_method(working, 'set_voxel', mirror, new_voxel, false, false)
								undo_redo.add_undo_method(working, 'set_voxel', mirror, voxel, false, false)
						Tools.COLOR_PICKER:
							var voxel = working.get_voxel(mirror)
							if voxel:
								undo_redo.add_do_method(self, 'set_paint_color', Voxel.get_color(voxel))
								undo_redo.add_undo_method(self, 'set_paint_color', PaintColor)
								break
				
				undo_redo.add_do_method(working, 'update')
				undo_redo.add_undo_method(working, 'update')
				
				undo_redo.commit_action()
				
				working.update_body(true)
				
				set_floor_visible(working.Voxels.size() == 0)
				
				return true
		else:
			for cursor in Cursors:
				cursor.visible = false
	else:
		for cursor in Cursors:
			cursor.visible = false
	
	return false