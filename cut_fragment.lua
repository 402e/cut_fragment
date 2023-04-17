local start_pos = nil

function toggle_mark()
    local pos = mp.get_property_number('time-pos')
    if start_pos then
        local end_pos = pos
        local cut_fragment_fmt = 'Cut fragment: %s - %s'

        if start_pos == end_pos then
            return print_msg('Cut fragment is empty')
        end

        if start_pos > end_pos then
            start_pos, end_pos = end_pos, start_pos
        end

        print_msg(cut_fragment_fmt:format(
                convert_time(start_pos),
                convert_time(end_pos))
            )
        cut(start_pos, end_pos)
        start_pos = nil
    else
        local marked_fmt = 'Marked %s as start position'
        start_pos = pos
        print_msg(marked_fmt:format(convert_time(start_pos)))
    end
end

function cut(start_pos, end_pos)
    local duration = end_pos - start_pos
    local out_name = get_out_name(start_pos, end_pos)

    mp.command_native_async(
        {
         name = 'subprocess',
         args = { 'ffmpeg', '-ss', string.format(start_pos),
                  '-accurate_seek', '-y', '-i', mp.get_property('path'),
                  '-t', string.format(duration),
                  '-c:v', 'copy', '-c:a', 'copy', 'file:' .. out_name },
        },
        function(success, result, error)
            if success then
                return print_msg('Finish cutting')
            end
            if error then
                return print_msg('Failed to encode: ' .. error)
            end
        end
    )
end

function print_msg(string)
    return mp.osd_message(string)
end

function convert_time(duration)
    local time_fmt = '%02d:%02d:%02.03f'
    local hours    = duration / 3600
    local minutes  = duration % 3600 / 60
    local seconds  = duration % 60
    return time_fmt:format(hours, minutes, seconds)
end

function get_out_name(start_pos, end_pos)
    local out_name_fmt = '%s_%s%s'
    local cut_time_fmt = '%s-%s'
    local name         = mp.get_property('filename')
    local ext          = name:match('^.+(%..+)$')
    local cut_time     = cut_time_fmt:format(
                                convert_time(start_pos),
                                convert_time(end_pos)
                            )
    name = name:gsub(ext, '')
    return out_name_fmt:format(name, cut_time, ext)
end

mp.add_key_binding('c', 'cut_fragment', toggle_mark)
