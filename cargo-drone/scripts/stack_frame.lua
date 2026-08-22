
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
function stack_frame.iterate(list, last_key, frame_buffer, func)
    if not frame_buffer.iterate_set then
        frame_buffer.iterate_set = true
        frame_buffer.iterate_key = next(list, last_key)
    end

    while frame_buffer.iterate_key do
        stack_frame.call(frame_buffer, func, frame_buffer.iterate_key, list[frame_buffer.iterate_key])

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

-- Reserved frame_buffer keys:
-- sequence_step
function stack_frame.sequence(frame_buffer, funcs)
    if frame_buffer.sequence_step == nil then
        frame_buffer.sequence_step = 1
    end

    for i = frame_buffer.sequence_step, #funcs do
        frame_buffer.sequence_step = i

        local should_break, status, ret_val = funcs[i]()

        if should_break then
            return status, ret_val
        end

        frame_buffer.iterate_set = nil
        frame_buffer.iterate_key = nil
    end
end

function stack_frame.sequence_iterator(list_and_key_getter, frame_buffer, func)
    return function()
        local list, key = list_and_key_getter()

        if stack_frame.iterate(list, key, frame_buffer, func) then
            return true, stack_frame.status, stack_frame.ret_val
        end
    end
end
function stack_frame.sequence_call(frame_buffer, func, args_getter)
    return function()
        if stack_frame.call(frame_buffer, func, args_getter()) then
            return true, stack_frame.status, stack_frame.ret_val
        end
    end
end

return stack_frame
