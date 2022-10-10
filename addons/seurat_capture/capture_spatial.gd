# This is the Spatial node that exports all settings for a single Seurat Capture
# It is created from the seurat_capture.gd editor plugin
@tool
extends Node3D

@export 
var cube_face_resolution: int = 512  # the resolution of a single cube face during capture
@export
var camera_near: float = 0.125  # the capture camera near plane distance
@export
var camera_far: float = 4096.0  # the capture camera far plane distance
@export
var center_resolution_scale: int = 4  # the center capture should be 4x resolution for anti aliasing

@export_global_dir
var export_path = "res://seurat_capture_images"  # the directory where the exported images and manifest is stored
var num_captures = 16  # number of samples inside the headbox (in addition to the center sample)

@export
var shadow_atlas_size = 4096

@export
var start_capture: bool = false

@export
var cancel_capture: bool = false

@export
var append_nodename_to_path: bool = false

@export
var append_settings_to_path: bool = false

var _capture_in_progress = false

var _editor: EditorInterface = null

func _ready():
	start_capture = false  # reset the start capture here
	cancel_capture = false
	_capture_in_progress = false


func _process(dt):
	if start_capture:
		if !_capture_in_progress:
			print("Starting Seurat Capture")
			perform_capture()

	if _capture_in_progress:
		start_capture = true
	else:
		start_capture = false

	if cancel_capture:
		if !_capture_in_progress:
			cancel_capture = false


func seurat_manifest_start_capture(mf: Dictionary):
	mf["view_groups"] = []
	return mf["view_groups"]


func seurat_manifest_start_viewgroup(mf: Dictionary):
	var view_group = {"views": []}
	mf["view_groups"].append(view_group)
	return view_group["views"]


func get_transform_as_matrixarray(c: Camera3D):
	var t = c.get_camera_transform()
	var b = t.basis.transposed()
	var o = t.origin
	return [
		b.x.x,
		b.x.y,
		b.x.z,
		o.x,
		b.y.x,
		b.y.y,
		b.y.z,
		o.y,
		b.z.x,
		b.z.y,
		b.z.z,
		o.z,
		0.0,
		0.0,
		0.0,
		1.0
	]


func get_projection_as_matrixarray(c: Camera3D):
	var S = 1.0 / tan(deg_to_rad(c.fov / 2))

	var f = c.far
	var n = c.near
	var a = -(f + n) / (f - n)
	var b = -(2 * f * n) / (f - n)
	return [S, 0.0, 0.0, 0.0, 0.0, S, 0.0, 0.0, 0.0, 0.0, a, b, 0.0, 0.0, -1.0, 0.0]


func seurat_manifest_get_view(vp: Viewport, cam: Camera3D, filenamePrefix):
	var ret = {
		"projective_camera":
		{
			"image_width": vp.size.x,
			"image_height": vp.size.y,
			"clip_from_eye_matrix": get_projection_as_matrixarray(cam),
			"world_from_eye_matrix": get_transform_as_matrixarray(cam),
			"depth_type": "EYE_Z",  #EYE_Z, WINDOW_Z
		},
		"depth_image_file":
		{
			"color":
			{
				"path": str(filenamePrefix, "color.exr"),
				"channel_0": "R",
				"channel_1": "G",
				"channel_2": "B",
				"channel_alpha": "CONSTANT_ONE"
			},
			"depth":
			{
				"path": str(filenamePrefix, "depth.exr"),
				"channel_0": "R",
			}
		},
	}
	return ret


# NOTE: doing this computation in float is not very precise for larger i but good enough for the few we need here
#       !!TODO: implement this using integer arithmetic instead of floats
func radicalInverse_vdC(base: int, i: int):
	var digit: float
	var radical: float
	var inverse: float
	digit = 1.0 / float(base)
	radical = digit
	inverse = 0.0
	while i > 0:
		inverse += digit * float(i % base)
		digit *= radical
		i /= base
	return float(inverse)


func saveDepthImage(captureVP : Viewport, filenamePrefix):
	var tex: ViewportTexture = captureVP.get_texture()
	var texData: Image = tex.get_image()
	texData.convert(Image.FORMAT_RH)
	if texData.save_exr(str(filenamePrefix, "depth.exr")) != OK:
		print("ERROR saving depth exr to ", str(filenamePrefix, "depth.exr"))


func saveColorImage(captureVP : Viewport, filenamePrefix):
	var texData = captureVP.get_texture().get_image()
	if texData.save_exr(str(filenamePrefix, "color.exr")) != OK:
		print("ERROR saving depth exr to ", str(filenamePrefix, "color.png"))


# setup the viewport to be able to capture everything we need
func set_viewport_for_capture(vp: Viewport):
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.positional_shadow_atlas_size = shadow_atlas_size


func create_depth_capture_quad():
	var screenSpaceQuad = MeshInstance3D.new()
	screenSpaceQuad.extra_cull_margin = INF
	var verts = PackedVector3Array()
	verts.append(Vector3(-1.0, -1.0, 0.0))
	verts.append(Vector3(-1.0, 3.0, 0.0))
	verts.append(Vector3(3.0, -1.0, 0.0))
	# Create an array of arrays.
	# This could contain normals, colors, UVs, etc.
	var mesh_array = []
	mesh_array.resize(Mesh.ARRAY_MAX) #required size for ArrayMesh Array
	mesh_array[Mesh.ARRAY_VERTEX] = verts #position of vertex array in ArrayMesh Array
	var mesh : ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mesh_array)
	var depthCaptureMaterial = ShaderMaterial.new()
	depthCaptureMaterial.shader = preload("capture_depth.gdshader")
	depthCaptureMaterial.set_shader_parameter("camera_near", camera_near)
	depthCaptureMaterial.set_shader_parameter("camera_far", camera_far)
	screenSpaceQuad.mesh = mesh
	screenSpaceQuad.visible = false
	screenSpaceQuad.set_surface_override_material(0, depthCaptureMaterial)
	return screenSpaceQuad


func perform_capture():
	if _editor == null:
		_editor = EditorPlugin.new().get_editor_interface()

	_capture_in_progress = true

	if _editor:
		_editor.get_selection().clear()

	for c in self.get_children():  # clean up everything before we add new things (only needed during testing)
		c.queue_free()

	var captureVP = Viewport.new()
	set_viewport_for_capture(captureVP)

	var captureCam = Camera3D.new()
	captureCam.near = camera_near
	captureCam.far = camera_far
	captureCam.current = true

	# create the screen space quad with the depth capture shader so we can render the depth values
	var screenSpaceQuad = create_depth_capture_quad()

	captureCam.add_child(screenSpaceQuad)  # the quad is a child of the camera so it gets transformed with it
	captureVP.add_child(captureCam)
	self.add_child(captureVP)

	# the dictionary that stores all the metadata of the capture; at the end it is stored as json in manifest.json
	# together with the images
	var seurat_manifest = {}
	seurat_manifest_start_capture(seurat_manifest)

	var path = export_path
	if append_nodename_to_path:
		path = str(path, "%s" % [name])
	if append_settings_to_path:
		path = str(
			path,
			(
				"_n%.1f_f%.0f_res%d_num%d"
				% [camera_near, camera_far, cube_face_resolution, num_captures]
			)
		)
	path = str(path, "/")

	print("Exporting to ", path)

	# create the output directory for the images and manifest
	if !DirAccess.dir_exists_absolute(path):
		if DirAccess.make_dir_recursive_absolute(path) != OK:
			print("ERROR: creating output directory", path, " failed!")

	var outFile : FileAccess = FileAccess.open(str(path, "manifest.json"), FileAccess.WRITE)
	if outFile == null:
		print("Error opening output file ", str(path, "manifest.json"))
		start_capture = false
		_capture_in_progress = false
		if _editor:
			_editor.get_selection().add_node(self)
		return

	# cube map look at positions and up vectors used below to setup the camera for each image capture
	var lookAtDirs = [
		Vector3(1, 0, 0),
		Vector3(0, 0, 1),
		Vector3(-1, 0, 0),
		Vector3(0, 0, -1),
		Vector3(0, 1, 0),
		Vector3(0, -1, 0)
	]
	var lookAtUps = [
		Vector3(0, 1, 0),
		Vector3(0, 1, 0),
		Vector3(0, 1, 0),
		Vector3(0, 1, 0),
		Vector3(1, 0, 0),
		Vector3(1, 0, 0)
	]

	var headbox_center = global_transform.origin

	var was_paused = get_tree().paused
	get_tree().paused = true  # pause so we have a static scene to capture

	# the headbox_center is the center of our capture box; this is stored here also in the manifest
	# to have the world space location of our capture; the seurat mesh is also created at this position since we
	# store the full camera matrix including the transform in the manifest
	seurat_manifest["headbox_center"] = [headbox_center.x, headbox_center.y, headbox_center.z]

	for viewGroup_i in range(0, num_captures):
		var view_group = seurat_manifest_start_viewgroup(seurat_manifest)

		var localPosition = Vector3(0, 0, 0)

		if viewGroup_i == 0:  # this should be the center of thew headbox
			captureVP.size.x = cube_face_resolution * center_resolution_scale  #should be 4x of the rest for anti aliasing
			captureVP.size.y = cube_face_resolution * center_resolution_scale

		else:
			captureVP.size.x = cube_face_resolution
			captureVP.size.y = cube_face_resolution

			var sx = (float(viewGroup_i) / float(num_captures)) * 2.0 - 1.0  # transform to [-1,1]
			var sy = radicalInverse_vdC(2, viewGroup_i) * 2.0 - 1.0
			var sz = radicalInverse_vdC(3, viewGroup_i) * 2.0 - 1.0

			localPosition = Vector3(sx, sy, sz)

		var camPosition = self.transform * localPosition

		print(
			" Capturing viewGroup ",
			viewGroup_i,
			"/",
			num_captures - 1,
			" camPosition: ",
			camPosition,
			" localPostion: ",
			localPosition
		)

		for view_i in range(0, lookAtDirs.size()):
			var viewDir = (self.transform.basis * lookAtDirs[view_i]).normalized()
			var upDir = (self.transform.basis * lookAtUps[view_i]).normalized()

			captureCam.fov = 90  # one cube face spans 90 degree viewing
			captureCam.look_at_from_position(camPosition, camPosition + viewDir, upDir)

			var filenamePrefix = "view%03d_cubeface%d_" % [viewGroup_i, view_i]
			
			screenSpaceQuad.visible = true  # first make the depth capture screen space quad visible and capture the depth
			var frame_delay = 4
			for i in range(frame_delay):
				await get_tree().physics_frame
			saveDepthImage(captureVP, str(path, filenamePrefix))
			screenSpaceQuad.visible = false
			for i in range(frame_delay):
				await get_tree().physics_frame
			saveColorImage(captureVP, str(path, filenamePrefix))

			# Save the current camera and image names in the dictionary so they end up in the manifest.json
			view_group.append(seurat_manifest_get_view(captureVP, captureCam, filenamePrefix))

			if cancel_capture:
				break
		if cancel_capture:
			break

#	remove_child(captureVP)
#	captureVP.queue_free()
	
	var json = JSON.new()
	var output_line : String = json.stringify(seurat_manifest)
	outFile.store_line(output_line)
	outFile.close()

	get_tree().paused = was_paused  # reset the state

	if cancel_capture:
		print("Capturing canceled")
	else:
		print("Capturing completed in ", path)

	_capture_in_progress = false
	cancel_capture = false
	start_capture = false

	if _editor:
		_editor.get_selection().add_node(self)
