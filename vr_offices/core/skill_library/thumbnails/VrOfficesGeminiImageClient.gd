extends RefCounted
class_name VrOfficesGeminiImageClient

const _Http := preload("res://addons/openagentic/core/OAMediaHttp.gd")

const MODEL := "gemini-3-pro-image-preview"
const DEFAULT_ASPECT := "1:1"
const DEFAULT_IMAGE_SIZE := "1K"
const DEFAULT_TIMEOUT_SEC := 30.0
const DEFAULT_THUMB_W := 640
const DEFAULT_THUMB_H := 360

func generate_thumbnail_png(
	prompt: String,
	base_url: String,
	api_key: String = "",
	transport: Callable = Callable(),
	options: Dictionary = {}
) -> Dictionary:
	var p := prompt.strip_edges()
	if p == "":
		return {"ok": false, "error": "EmptyPrompt"}
	var bu := base_url.strip_edges().rstrip("/")
	if bu == "":
		return {"ok": false, "error": "EmptyBaseUrl"}

	var aspect := String(options.get("aspect_ratio", DEFAULT_ASPECT)).strip_edges()
	if aspect == "":
		aspect = DEFAULT_ASPECT
	var img_size := String(options.get("image_size", DEFAULT_IMAGE_SIZE)).strip_edges()
	if img_size == "":
		img_size = DEFAULT_IMAGE_SIZE
	var w := int(options.get("thumb_width", 0))
	var h := int(options.get("thumb_height", 0))
	if w <= 0 or h <= 0:
		var sz := int(options.get("thumb_size", 0))
		if sz > 0:
			w = sz
			h = sz
	if w <= 0:
		w = DEFAULT_THUMB_W
	if h <= 0:
		h = DEFAULT_THUMB_H
	var timeout := float(options.get("timeout_sec", DEFAULT_TIMEOUT_SEC))

	var payload := {
		"contents": [{"parts": [{"text": p}]}],
		"generationConfig": {
			"responseModalities": ["IMAGE"],
			"imageConfig": {"aspectRatio": aspect, "imageSize": img_size},
		},
	}

	var url := bu + "/v1beta/models/%s:generateContent" % MODEL
	var headers := {
		"content-type": "application/json",
		"accept": "application/json",
	}
	var key := api_key.strip_edges()
	if key != "":
		headers["x-goog-api-key"] = key

	var body := JSON.stringify(payload).to_utf8_buffer()
	var opts := options.duplicate()
	opts.erase("aspect_ratio")
	opts.erase("image_size")
	opts.erase("thumb_size")
	opts.erase("timeout_sec")

	var r: Dictionary = await _Http.request(HTTPClient.METHOD_POST, url, headers, body, timeout, transport, opts)
	if not bool(r.get("ok", false)):
		return {"ok": false, "error": String(r.get("error", "HttpFailed")), "status": int(r.get("status", 0))}

	var status := int(r.get("status", 0))
	var bytes: PackedByteArray = r.get("body", PackedByteArray())
	var txt := bytes.get_string_from_utf8()
	if status < 200 or status >= 300:
		return {"ok": false, "error": "HttpStatus", "status": status, "body": txt}

	var parsed: Variant = JSON.parse_string(txt)
	var pick := find_first_inline_data(parsed)
	if not bool(pick.get("ok", false)):
		return {"ok": false, "error": "MissingInlineData"}

	var b64 := String(pick.get("data", "")).strip_edges()
	var mime := String(pick.get("mime", "")).strip_edges().to_lower()
	var raw := Marshalls.base64_to_raw(b64)
	if raw.size() <= 0:
		return {"ok": false, "error": "BadBase64"}

	var conv := to_png_bytes(raw, mime, w, h)
	if not bool(conv.get("ok", false)):
		return conv
	return {"ok": true, "png_bytes": conv.get("png_bytes", PackedByteArray()), "source_mime": mime}

static func find_first_inline_data(v: Variant) -> Dictionary:
	if typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v as Dictionary
		var id0: Variant = null
		if d.has("inlineData"):
			id0 = d.get("inlineData")
		elif d.has("inline_data"):
			id0 = d.get("inline_data")
		if typeof(id0) == TYPE_DICTIONARY:
			var id: Dictionary = id0 as Dictionary
			var data := String(id.get("data", "")).strip_edges()
			var mime := String(id.get("mimeType", id.get("mime_type", ""))).strip_edges()
			if data != "":
				return {"ok": true, "data": data, "mime": mime}
		for k in d.keys():
			var r := find_first_inline_data(d.get(k))
			if bool(r.get("ok", false)):
				return r
		return {"ok": false}

	if typeof(v) == TYPE_ARRAY:
		for it in v as Array:
			var r2 := find_first_inline_data(it)
			if bool(r2.get("ok", false)):
				return r2
		return {"ok": false}

	return {"ok": false}

static func to_png_bytes(raw: PackedByteArray, mime: String, width: int, height: int) -> Dictionary:
	var img := Image.new()
	var err := ERR_UNAVAILABLE
	var m := mime.strip_edges().to_lower()
	if m.find("png") != -1:
		err = img.load_png_from_buffer(raw)
	elif m.find("jpeg") != -1 or m.find("jpg") != -1:
		err = img.load_jpg_from_buffer(raw)
	elif m.find("webp") != -1:
		err = img.load_webp_from_buffer(raw)
	else:
		err = img.load_png_from_buffer(raw)
		if err != OK:
			err = img.load_jpg_from_buffer(raw)
	if err != OK:
		return {"ok": false, "error": "ImageDecodeFailed", "code": err, "mime": m}

	var w := width
	var h := height
	if w <= 0:
		w = img.get_width()
	if h <= 0:
		h = img.get_height()
	if img.get_width() != w or img.get_height() != h:
		img.resize(w, h, Image.INTERPOLATE_LANCZOS)
	var out := img.save_png_to_buffer()
	if out.size() <= 0:
		return {"ok": false, "error": "PngEncodeFailed"}
	return {"ok": true, "png_bytes": out}
