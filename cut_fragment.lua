local utils = require("mp.utils")
local start_pos = nil

mp.register_event("file-loaded", function()
  start_pos = nil
end)

function get_selected_maps()
  local maps = {}

  local function add_track(track_type)
    local ff_index = mp.get_property_native("current-tracks/" .. track_type .. "/ff-index")

    if type(ff_index) == "number" and ff_index >= 0 then
      maps[#maps + 1] = "0:" .. tostring(ff_index)
    end
  end

  local video_index = mp.get_property_native("current-tracks/video/ff-index")

  if type(video_index) ~= "number" or video_index < 0 then
    return nil, "No video track selected"
  end

  add_track("video")
  add_track("audio")

  local subtitles_selected = mp.get_property("sid") ~= "no"
  local subtitles_visible = mp.get_property_native("sub-visibility")

  if subtitles_selected and subtitles_visible then
    add_track("sub")
  end

  return maps
end

function toggle_mark()
  local pos, err = mp.get_property_number("time-pos")

  if pos == nil then
    return print_msg("Playback position is unavailable")
  end

  if start_pos then
    local end_pos = pos
    local cut_fragment_fmt = "Cut fragment: %s - %s"

    if start_pos == end_pos then
      return print_msg("Cut fragment is empty")
    end

    if start_pos > end_pos then
      start_pos, end_pos = end_pos, start_pos
    end

    print_msg(cut_fragment_fmt:format(convert_time(start_pos), convert_time(end_pos)))
    cut(start_pos, end_pos)
    start_pos = nil
  else
    local marked_fmt = "Marked %s as start position"
    start_pos = pos
    print_msg(marked_fmt:format(convert_time(start_pos)))
  end
end

function cut(start_pos, end_pos)
  local duration = end_pos - start_pos
  local out_name = get_out_name(start_pos, end_pos)

  if not out_name then
    return print_msg("Cannot determine output path")
  end

  local maps, map_error = get_selected_maps()

  if not maps then
    return print_msg(map_error)
  end

  local args = {
    "ffmpeg",
    "-ss",
    string.format("%.6f", start_pos),
    "-seek2any",
    "0",
    "-y",
    "-i",
    mp.get_property("path"),
    "-t",
    string.format("%.6f", duration),
  }

  for _, map in ipairs(maps) do
    args[#args + 1] = "-map"
    args[#args + 1] = map
  end

  args[#args + 1] = "-c"
  args[#args + 1] = "copy"
  args[#args + 1] = "-avoid_negative_ts"
  args[#args + 1] = "make_zero"
  args[#args + 1] = out_name

  mp.command_native_async({
    name = "subprocess",
    args = args,
    capture_stderr = true,
    playback_only = false,
  }, function(success, result, error)
    if not success then
      return print_msg("mpv failed to run FFmpeg: " .. tostring(error))
    end

    if not result or result.status ~= 0 then
      local details = result and result.stderr

      if not details or details == "" then
        details = result and result.error_string
      end

      return print_msg("FFmpeg failed: " .. tostring(details or "unknown error"))
    end

    print_msg("Finished cutting")
  end)
end

function print_msg(string)
  return mp.osd_message(string)
end

function convert_time(duration)
  local time_fmt = "%02d:%02d:%06.3f"

  local hours = math.floor(duration / 3600)
  local minutes = math.floor((duration % 3600) / 60)
  local seconds = duration % 60

  return time_fmt:format(hours, minutes, seconds)
end

function get_out_name(start_pos, end_pos)
  local path = mp.get_property("path")

  if not path then
    return nil
  end

  local directory, filename = utils.split_path(path)
  local name, ext = filename:match("^(.*)(%.[^.]*)$")

  name = name or filename
  ext = ext or ""

  local start_time = convert_time(start_pos):gsub(":", "-")
  local end_time = convert_time(end_pos):gsub(":", "-")

  local output_name = string.format("%s_%s-%s%s", name, start_time, end_time, ext)

  return utils.join_path(directory, output_name)
end

mp.add_key_binding("c", "cut_fragment", toggle_mark)
