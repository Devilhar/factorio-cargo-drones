
local stack_frame = {}

stack_frame.yield = {}
stack_frame.complete = {}
stack_frame.continue_and_yield = {}

stack_frame.status = stack_frame.yield
stack_frame.ret_val = nil

function stack_frame.create_buffer()
    return {}
end

function stack_frame.call(frame_buffer, func, ...)
    if not frame_buffer.next_frame then
        frame_buffer.next_frame = {}
    end

    stack_frame.status, stack_frame.ret_val = func(frame_buffer.next_frame, ...)

    if stack_frame.status == stack_frame.yield then
        return true, stack_frame.ret_val
    end

    frame_buffer.next_frame = nil

    return false, stack_frame.ret_val
end

-- Reserved frame_buffer keys:
-- iterate_set
-- iterate_key
function stack_frame.iterate(list, last_key, frame_buffer, func, ...)
    if not frame_buffer.iterate_set then
        frame_buffer.iterate_set = true
        frame_buffer.iterate_key = next(list, last_key)
    end

    while frame_buffer.iterate_key do
        stack_frame.call(frame_buffer, func, frame_buffer.iterate_key, list[frame_buffer.iterate_key], ...)

        if stack_frame.status == stack_frame.complete then
            frame_buffer = nil

            return true, stack_frame.ret_val
        end

        if stack_frame.status == stack_frame.yield then
            return true, stack_frame.ret_val
        end

        frame_buffer.iterate_key = next(list, frame_buffer.iterate_key)

        if stack_frame.status == stack_frame.continue_and_yield then
            stack_frame.status = stack_frame.yield

            return true, stack_frame.ret_val
        end
    end

    return false
end

return stack_frame
