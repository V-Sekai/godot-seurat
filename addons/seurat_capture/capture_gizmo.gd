# Gizmo used to show the SeuraCaptureBox settings on the capture_spatial
# At the moment it has no additional information and just shows the std. scale box as boundaries
@tool
extends EditorNode3DGizmoPlugin

const CaptureSpatial = preload("res://addons/seurat_capture/capture_spatial.gd")


func _get_gizmo_name():
	return "SeuratCaptureBox"


func _has_gizmo(spatial):
	return spatial is CaptureSpatial


func _redraw(gizmo):
	gizmo.clear()

	var spatial = gizmo.get_spatial_node()

	var lines = PackedVector3Array()

	# the wireframe box of the capture volume
	lines.push_back(Vector3(-1, -1, -1))  #front
	lines.push_back(Vector3(1, -1, -1))
	lines.push_back(Vector3(1, -1, -1))
	lines.push_back(Vector3(1, 1, -1))
	lines.push_back(Vector3(1, 1, -1))
	lines.push_back(Vector3(-1, 1, -1))
	lines.push_back(Vector3(-1, 1, -1))
	lines.push_back(Vector3(-1, -1, -1))

	lines.push_back(Vector3(-1, -1, 1))  #back
	lines.push_back(Vector3(1, -1, 1))
	lines.push_back(Vector3(1, -1, 1))
	lines.push_back(Vector3(1, 1, 1))
	lines.push_back(Vector3(1, 1, 1))
	lines.push_back(Vector3(-1, 1, 1))
	lines.push_back(Vector3(-1, 1, 1))
	lines.push_back(Vector3(-1, -1, 1))

	lines.push_back(Vector3(-1, -1, -1))  #side lines
	lines.push_back(Vector3(-1, -1, 1))
	lines.push_back(Vector3(1, -1, -1))
	lines.push_back(Vector3(1, -1, 1))
	lines.push_back(Vector3(1, 1, -1))
	lines.push_back(Vector3(1, 1, 1))
	lines.push_back(Vector3(-1, 1, -1))
	lines.push_back(Vector3(-1, 1, 1))

	gizmo.add_lines(lines, get_material("main", gizmo), false)


func _init():
	create_material("main", Color(1, 0, 0))
	
