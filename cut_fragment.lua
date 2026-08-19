local start_pos = nil

mp.register_event("file-loaded", function()
  start_pos = nil
end)

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

  mp.command_native_async({
    name = "subprocess",
    args = {
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
      "-c:v",
      "copy",
      "-c:a",
      "copy",
      "-avoid_negative_ts",
      "make_zero",
      "file:" .. out_name,
    },
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
  local out_name_fmt = "%s_%s%s"
  local cut_time_fmt = "%s-%s"
  local name = mp.get_property("filename")
  local ext = name:match("^.+(%..+)$")
  local cut_time = cut_time_fmt:format(convert_time(start_pos), convert_time(end_pos))
  name = name:gsub(ext, "")
  return out_name_fmt:format(name, cut_time, ext)
end

mp.add_key_binding("c", "cut_fragment", toggle_mark)
