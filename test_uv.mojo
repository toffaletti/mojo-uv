from testing import assert_false, assert_true, assert_equal, assert_raises
import uv


def test_loop():
    with uv.Loop.default() as loop:
        _ = loop.run(uv.UV_RUN_ONCE)
        assert_false(loop.alive())


def test_idle():
    with uv.Loop.new() as loop:
        var counter = 0

        @parameter
        fn idler() -> Bool:
            counter += 1
            if counter == 10:
                return False
            return True

        idle = uv.IdleHandle.new[idler](loop)

        idle.start()
        assert_true(idle.h.is_active())
        assert_equal(idle.h.loop(), loop)
        r = loop.run()
        assert_equal(counter, 10)
        assert_equal(r, 0)
        assert_true(idle.h.has_ref())
        assert_false(idle.h.is_active())
        assert_false(idle.h.is_closing())
        idle.h.close()
        assert_true(idle.h.is_closing())
        # run loop again for close to take effect
        r = loop.run()
        assert_equal(r, 0)
        # true if closing or closed
        assert_true(idle.h.is_closing())


def test_timer():
    with uv.Loop.new() as loop:
        var t: uv.TimerHandle
        var counter = 0

        @parameter
        fn timer():
            counter += 1

        t = uv.TimerHandle.new[timer](loop)

        t.start(1, 0)
        assert_true(t.h.is_active())
        assert_equal(t.h.loop(), loop)
        r = loop.run()
        assert_equal(counter, 1)
        assert_equal(r, 0)
        assert_true(t.h.has_ref())
        assert_false(t.h.is_active())
        assert_false(t.h.is_closing())
        t.h.close()
        assert_true(t.h.is_closing())
        # run loop again for close to take effect
        r = loop.run()
        assert_equal(r, 0)
        # true if closing or closed
        assert_true(t.h.is_closing())
