tool
extends Control



# Imports
const VoxelButton := preload("res://addons/Voxel-Core/controls/VoxelButton/VoxelButton.tscn")



# Refrences
onready var SearchRef := get_node("VBoxContainer/Search")

onready var Voxels := get_node("VBoxContainer/ScrollContainer/Voxels")

onready var Hints := get_node("VBoxContainer/Hints")
onready var HintRef := get_node("VBoxContainer/Hints/Hint")

onready var ContextMenu := get_node("ContextMenu")



# Declarations
signal selected(index)
signal unselecting(index)
signal unselected(index)


export(bool) var EditMode := false setget set_edit_mode
func set_edit_mode(edit_mode : bool, update := true) -> void:
	EditMode = edit_mode
	
	if update: _update()



var Selections := [] setget set_selections
func set_selections(selections : Array) -> void: pass

export(bool) var SelectMode := false setget set_select_mode
func set_select_mode(select_mode : bool) -> void:
	SelectMode = select_mode
	if not SelectMode: unselect_all()

export(int, 0, 1000000000) var SelectionMax := 0 setget set_selection_max
func set_selection_max(selection_max : int) -> void:
	selection_max = abs(selection_max)
	if selection_max > 0 and selection_max < SelectionMax:
		var size = Selections.size()
		while size > selection_max:
			unselect(size - 1)
			size = Selections.size()
	
	SelectionMax = selection_max


export(String) var Search := "" setget set_search
func set_search(search : String, update := true) -> void:
	Search = search
	
	if SearchRef: SearchRef.text = search
	if update: _update()


export(Resource) var Voxel_Set = load("res://addons/Voxel-Core/defaults/VoxelSet.tres") setget set_voxel_set
func set_voxel_set(voxel_set : Resource, update := true) -> void:
	if voxel_set is VoxelSet:
		if is_instance_valid(Voxel_Set):
			if Voxel_Set.is_connected("updated_voxels", self, "_update"):
				Voxel_Set.disconnect("updated_voxels", self, "_update")
			if Voxel_Set.is_connected("updated_texture", self, "_update"):
				Voxel_Set.disconnect("updated_texture", self, "_update")
		Voxel_Set = voxel_set
		Voxel_Set.connect("updated_voxels", self, "_update")
		Voxel_Set.connect("updated_texture", self, "_update")
		
		if update: _update()
	elif typeof(voxel_set) == TYPE_NIL:
		set_voxel_set(load("res://addons/Voxel-Core/defaults/VoxelSet.tres"), update)



# Core
func _ready():
	set_voxel_set(VoxelSet)


func correct() -> void:
	if Voxels: Voxels.columns = int(floor(rect_size.x / 36))


func select(voxel_id, voxel_ref) -> int:
	if SelectMode:
		if SelectionMax == 0 or Selections.size() < SelectionMax:
			voxel_ref.pressed = true
			Selections.append([
				voxel_id,
				voxel_ref
			])
		else:
			unselect(Selections.size() - 1)
			return select(voxel_id, voxel_ref)
		emit_signal("selected", Selections.size() - 1)
		return Selections.size() - 1
	else: return -1

func unselect(index : int) -> void:
	if index > Selections.size():
		printerr("unselect index out of range: ", index)
		return
	emit_signal("unselecting", index)
	if is_instance_valid(Selections[index][1]):
		Selections[index][1].pressed = false
	Selections.remove(index)
	emit_signal("unselected", index)

func unselect_all() -> void:
	while not Selections.empty():
			unselect(Selections.size() - 1)


func _update() -> void:
	if Voxels and is_instance_valid(Voxel_Set):
		var voxels := []
		if Search.length() == 0:
			voxels = Voxel_Set.Voxels.keys()
			for name in Voxel_Set.Names:
				voxels[voxels.find(Voxel_Set.name_to_id(name))] = name
		else:
			for key in Search.to_lower().split(","):
				if key.is_valid_integer():
					key = key.to_int()
					if not voxels.has(key) and Voxel_Set.Voxels.has(key):
						voxels.append(key)
				else:
					for name in Voxel_Set.Names:
						if name.find(key) > -1:
							var index := voxels.find(Voxel_Set.name_to_id(name))
							if index > -1:
								voxels[index] = name
							else: voxels.append(name)
		
		for child in Voxels.get_children():
			Voxels.remove_child(child)
			child.queue_free()
		
		for voxel in voxels:
			var voxel_ref = VoxelButton.instance()
			voxel_ref.name = str(voxel)
			voxel_ref.toggle_mode = true
			voxel_ref.mouse_filter = Control.MOUSE_FILTER_PASS
			voxel_ref.connect("pressed", self, "_on_VoxelButton_pressed", [voxel, voxel_ref])
			voxel_ref.setup_voxel(voxel, Voxel_Set)
			Voxels.add_child(voxel_ref)
		
		for selection in range(Selections.size()):
			var voxel_ref = Voxels.find_node(
				str(Selections[selection][0]),
				false,
				false
			)
			
			if is_instance_valid(voxel_ref):
				voxel_ref.pressed = true
				Selections[selection][1] = voxel_ref
			else: unselect(selection)
	
	if Hints:
		Hints.visible = EditMode or SelectMode
		if HintRef:
			HintRef.text = ""
			if EditMode: HintRef.text += "right click : context menu"
			if SelectMode: HintRef.text += ("   " if HintRef.text.length() > 0 else "")  + "ctrl + left click : select / unselect"
	
	call_deferred("correct")


func _on_Search_text_changed(new_text):
	Search = new_text
	_update()


func _on_Voxels_gui_input(event):
	if EditMode and event is InputEventMouseButton and event.button_index == BUTTON_RIGHT:
		ContextMenu.clear()
		ContextMenu.add_icon_item(
			preload("res://addons/Voxel-Core/assets/controls/add.png"),
			"Add voxel", 0
		)
		if Selections.size() == 1:
			ContextMenu.add_icon_item(
				preload("res://addons/Voxel-Core/assets/controls/duplicate.png"),
				"Duplicate voxel", 1
			)
			ContextMenu.add_icon_item(
				preload("res://addons/Voxel-Core/assets/controls/sub.png"),
				"Remove voxel", 2
			)
		elif Selections.size() > 1:
			ContextMenu.add_separator()
			ContextMenu.add_icon_item(
				preload("res://addons/Voxel-Core/assets/controls/cancel.png"),
				"Deselect voxels", 3
			)
			ContextMenu.add_icon_item(
				preload("res://addons/Voxel-Core/assets/controls/duplicate.png"),
				"Duplicate voxels", 4
			)
			ContextMenu.add_icon_item(
				preload("res://addons/Voxel-Core/assets/controls/sub.png"),
				"Remove voxels", 5
			)
		ContextMenu.set_as_minsize()
		
		ContextMenu.popup(Rect2(
			event.global_position,
			ContextMenu.rect_size
		))


func _on_VoxelButton_pressed(voxel_id, voxel_ref) -> void:
	if SelectMode:
		if voxel_ref.pressed:
			if not Input.is_key_pressed(KEY_CONTROL):
				unselect_all()
			select(voxel_id, voxel_ref)
		else:
			if Selections.size() == 1 or (Selections.size() > 0 and Input.is_key_pressed(KEY_CONTROL)):
				for selection in range(Selections.size()):
					if Selections[selection][0] == voxel_id:
						unselect(selection)
						break
			else:
				unselect_all()
				select(voxel_id, voxel_ref)
	else: voxel_ref.pressed = false


func _on_ContextMenu_id_pressed(id : int):
	match id:
		0: Voxel_Set.set_voxel(Voxel.colored(Color.white))
		1: Voxel_Set.set_voxel(Voxel_Set.get_voxel(Selections[0]).duplicate(true))
		2: Voxel_Set.erase_voxel(Selections[0])
		3: unselect_all()
		4:
			for selection in Selections:
				Voxel_Set.set_voxel(Voxel_Set.get_voxel(selection).duplicate(true), Voxel_Set.get_id(), false)
			Voxel_Set.updated_voxels()
		5: 
			for selection in Selections:
				Voxel_Set.erase_voxel(selection, false)
			Voxel_Set.updated_voxels()
