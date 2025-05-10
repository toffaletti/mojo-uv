import uv


def main():
    var counter = 0

    @parameter
    fn idler() -> Bool:
        counter += 1
        if counter == 10:
            return False
        return True

    @parameter
    fn timer():
        print("yay")
        counter += 1

    # print("uv_loop_size:", uv.uv_loop_size())
    with uv.Loop.default() as loop,
        uv.IdleHandle.new[idler](loop) as idle,
        uv.TimerHandle.new[timer](loop) as t:

        _ = loop.run(uv.UV_RUN_ONCE)

        # idle = uv.IdleHandle.new[idler](loop)
        idle.start()
        print("alive:", loop.alive())
        print("idle is active:", idle.h.is_active())
        _ = loop.run()
        # XXX: if using @parameter on idler
        # must reference counter here otherwise
        # the idle loop is infinite
        print("counter:", counter)
        print("alive:", loop.alive())
        # idle.h.close()
        # idle.h.unref()
        print("idle is active:", idle.h.is_active())
        print("idle is closing:", idle.h.is_closing())
        while loop.alive():
            _ = loop.run()

        # var t = uv.TimerHandle.new[timer](loop)

        t.start(1, 0)
        _ = loop.run()
        # t.h.close()
        # print(t.h.is_active())

    # nloop = uv.Loop.new()
    # _ = nloop.run()
    # with uv.Loop() as loop:
    #     _ = loop.run(uv.UV_RUN_ONCE)
