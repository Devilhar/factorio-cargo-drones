
local frame = {}

frame.yield = {}
frame.complete = {}
frame.continue_and_yield = {}

frame.status = frame.yield
frame.ret_val = nil

function frame.create_buffer()
    return {}
end

function frame.call(frame_buffer, func, ...)
    if not frame_buffer.next_frame then
        frame_buffer.next_frame = {}
    end

    frame.status, frame.ret_val = func(frame_buffer.next_frame, ...)

    if frame.status == frame.yield then
        return true, frame.ret_val
    end

    frame_buffer.next_frame = nil

    return false, frame.ret_val
end

function frame.iterate(list, last_key, frame_buffer, func, ...)
    if not frame_buffer.next_frame then
        frame_buffer.next_frame = {
            key = next(list, last_key),
        }
    end

    while frame_buffer.next_frame.key do
        frame.call(frame_buffer.next_frame, func, frame_buffer.next_frame.key, list[frame_buffer.next_frame.key], ...)

        if frame.status == frame.complete then
            frame_buffer.next_frame = nil

            return true, frame.ret_val
        end

        if frame.status == frame.yield then
            return true, frame.ret_val
        end

        frame_buffer.next_frame.key = next(list, frame_buffer.next_frame.key)

        if frame.status == frame.continue_and_yield then
            frame.status = frame.yield

            return true, frame.ret_val
        end
    end

    frame_buffer.next_frame = nil

    return false
end

return frame
