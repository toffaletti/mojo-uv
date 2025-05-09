import uv


def main():
    # print("uv_loop_size:", uv.uv_loop_size())
    with uv.Loop.default() as loop:
        _ = loop.run(uv.UV_RUN_ONCE)
        idle = uv.IdleHandle(loop)

        fn idler() -> Bool:
            print("idle")
            return False

        idle.start[idler]()
        print("alive:", loop.alive())
        _ = loop.run()
        print("alive:", loop.alive())
        idle.h.close()
        while loop.alive():
            _ = loop.run()

    # nloop = uv.Loop.new()
    # _ = nloop.run()
    # with uv.Loop() as loop:
    #     _ = loop.run(uv.UV_RUN_ONCE)
