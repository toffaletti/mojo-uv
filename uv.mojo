from memory import UnsafePointer, stack_allocation, OwnedPointer, ArcPointer
from pathlib import Path
from utils import Variant
from os.atomic import Atomic
from sys.ffi import c_char, c_int, c_uint, c_size_t, c_long_long
from sys.ffi import _get_dylib_function as _ffi_get_dylib_function
from sys.ffi import _Global, _OwnedDLHandle, _find_dylib

# from collections import OptionalReg

alias UV_LIBRARY_PATHS = List[Path](
    "libuv.so",
    "libuv.dylib",
)

alias UV_LIBRARY = _Global["UV_LIBRARY", _OwnedDLHandle, _init_dylib]


fn _init_dylib() -> _OwnedDLHandle:
    return _find_dylib(UV_LIBRARY_PATHS)


@always_inline
fn _get_dylib_function[
    func_name: StaticString, result_type: AnyTrivialRegType
]() -> result_type:
    return _ffi_get_dylib_function[UV_LIBRARY(), func_name, result_type]()


alias uv_run_mode = c_int
alias UV_RUN_DEFAULT = uv_run_mode(0)
alias UV_RUN_ONCE = uv_run_mode(1)
alias UV_RUN_NOWAIT = uv_run_mode(2)


struct Ref[T: AnyType](Movable):
    var ptr: UnsafePointer[T]

    fn __init__(out self, ptr: UnsafePointer[T]):
        self.ptr = ptr

    fn __del__(owned self):
        self.ptr.free()

    fn __moveinit__(out self, owned existing: Self):
        self.ptr = existing.ptr


# XXX: leak the Loop pointer so we don't call free
var _default_loop = _make_default_loop()


fn _make_default_loop() -> UnsafePointer[Loop]:
    ptr = UnsafePointer[Loop].alloc(1)
    ptr.init_pointee_move(Loop(uv_default_loop(), is_owned=False))
    return ptr


@register_passable
struct Loop(Copyable, Movable, EqualityComparable, Stringable):
    var _ptr: ArcPointer[Ref[uv_loop_t]]

    @staticmethod
    fn default() -> Loop:
        return _default_loop[]

    @staticmethod
    fn new() raises -> Loop:
        var size = uv_loop_size()
        var buf = UnsafePointer[c_char].alloc(size)
        loop = Loop(buf.bitcast[uv_loop_t](), is_owned=True)
        r = uv_loop_init(loop.unsafe_ptr())
        if r != 0:
            raise_uverr["init failed"](r)
        return loop^

    fn __init__(out self, loop: uv_loop_ptr, is_owned: Bool):
        self._ptr = ArcPointer(Ref(loop))

    fn __copyinit__(out self, existing: Self):
        self._ptr = existing._ptr

    fn __eq__(self, other: Self) -> Bool:
        return self.unsafe_ptr() == other.unsafe_ptr()

    fn __ne__(self, other: Self) -> Bool:
        return self.unsafe_ptr() != other.unsafe_ptr()

    fn __str__(self) -> String:
        return "loop[" + String(self._ptr[].ptr) + "]"

    fn __enter__(self) -> Self:
        return self

    fn __exit__(self) raises:
        # allow close callbacks to run
        _ = self.run(uv.UV_RUN_ONCE)
        self.close()

    fn unsafe_ptr(self) -> uv_loop_ptr:
        return self._ptr[].ptr

    fn close(self) raises:
        r = uv_loop_close(self.unsafe_ptr())
        if r != 0:
            raise_uverr["close failed"](r)

    fn run(self, mode: uv_run_mode = UV_RUN_DEFAULT) -> Int:
        return Int(uv_run(self.unsafe_ptr(), mode))

    fn alive(self) -> Bool:
        return Bool(uv_loop_alive(self.unsafe_ptr()))

    fn get_data[T: AnyType](self) -> UnsafePointer[T]:
        return uv_loop_get_data[T](self.unsafe_ptr())

    fn set_data[T: AnyType](self, data: UnsafePointer[T]):
        return uv_loop_set_data(self.unsafe_ptr(), data)


fn uv_strerror(err: c_int) -> UnsafePointer[c_char]:
    return _get_dylib_function[
        "uv_strerror",
        fn (c_int) -> UnsafePointer[c_char],
    ]()(err)


fn uv_err_name(err: c_int) -> UnsafePointer[c_char]:
    return _get_dylib_function[
        "uv_err_name",
        fn (c_int) -> UnsafePointer[c_char],
    ]()(err)


@always_inline
fn raise_uverr[msg: StaticString](err: c_int) raises:
    errname_ptr = uv_err_name(err)
    errname = StringSlice[origin = errname_ptr.origin](
        unsafe_from_utf8_ptr=errname_ptr
    )

    errmsg_ptr = uv_strerror(err)
    errmsg = StringSlice[origin = errmsg_ptr.origin](
        unsafe_from_utf8_ptr=errmsg_ptr
    )
    raise Error(msg + " [" + errname + "]: " + errmsg)


struct uv_loop_t:
    pass


alias uv_loop_ptr = UnsafePointer[uv_loop_t]


fn uv_default_loop() -> (
    UnsafePointer[uv_loop_t, mut=False, origin=StaticConstantOrigin]
):
    return _get_dylib_function[
        "uv_default_loop",
        fn () -> UnsafePointer[
            uv_loop_t, mut=False, origin=StaticConstantOrigin
        ],
    ]()()


fn uv_loop_size() -> c_size_t:
    return _get_dylib_function[
        "uv_loop_size",
        fn () -> c_size_t,
    ]()()


fn uv_loop_init(ptr: uv_loop_ptr) -> c_int:
    return _get_dylib_function[
        "uv_loop_init",
        fn (uv_loop_ptr) -> c_int,
    ]()(ptr)


fn uv_loop_close(ptr: uv_loop_ptr) -> c_int:
    return _get_dylib_function[
        "uv_loop_close",
        fn (uv_loop_ptr) -> c_int,
    ]()(ptr)


fn uv_run(ptr: uv_loop_ptr, mode: uv_run_mode) -> c_int:
    return _get_dylib_function[
        "uv_run",
        fn (uv_loop_ptr, c_int) -> c_int,
    ]()(ptr, mode)


fn uv_loop_alive(ptr: uv_loop_ptr) -> c_int:
    return _get_dylib_function[
        "uv_loop_alive",
        fn (uv_loop_ptr) -> c_int,
    ]()(ptr)


fn uv_loop_get_data[T: AnyType](ptr: uv_loop_ptr) -> UnsafePointer[T]:
    return _get_dylib_function[
        "uv_loop_get_data",
        fn (uv_loop_ptr) -> UnsafePointer[T],
    ]()(ptr)


fn uv_loop_set_data[T: AnyType](ptr: uv_loop_ptr, data: UnsafePointer[T]):
    return _get_dylib_function[
        "uv_loop_set_data",
        fn (uv_loop_ptr, UnsafePointer[T]),
    ]()(ptr, data)


fn uv_loop_configure(ptr: uv_loop_ptr, option: c_int) -> c_int:
    return _get_dylib_function[
        "uv_loop_configure",
        fn (uv_loop_ptr, /, * options: c_int) -> c_int,
    ]()(ptr, option)


# Handles
alias uv_handle_type = c_int
alias UV_UNKNOWN_HANDLE = uv_handle_type(0)
alias UV_ASYNC = uv_handle_type(1)
alias UV_CHECK = uv_handle_type(2)
alias UV_FS_EVENT = uv_handle_type(3)
alias UV_FS_POLL = uv_handle_type(4)
alias UV_HANDLE = uv_handle_type(5)
alias UV_IDLE = uv_handle_type(6)
alias UV_NAMED_PIPE = uv_handle_type(7)
alias UV_POLL = uv_handle_type(8)
alias UV_PREPARE = uv_handle_type(9)
alias UV_PROCESS = uv_handle_type(10)
alias UV_STREAM = uv_handle_type(11)
alias UV_TCP = uv_handle_type(12)
alias UV_TIMER = uv_handle_type(13)
alias UV_TTY = uv_handle_type(14)
alias UV_UDP = uv_handle_type(15)
alias UV_SIGNAL = uv_handle_type(16)
alias UV_FILE = uv_handle_type(17)


struct uv_handle_t:
    pass


alias uv_handle_ptr = UnsafePointer[uv_handle_t]


fn uv_handle_size(type: uv_handle_type) -> c_size_t:
    return _get_dylib_function[
        "uv_handle_size",
        fn (uv_handle_type) -> c_size_t,
    ]()(type)


fn uv_handle_get_type(handle: uv_handle_ptr) -> uv_handle_type:
    return _get_dylib_function[
        "uv_handle_get_type",
        fn (uv_handle_ptr) -> uv_handle_type,
    ]()(handle)


fn uv_handle_get_data[T: AnyType](ptr: uv_handle_ptr) -> UnsafePointer[T]:
    return _get_dylib_function[
        "uv_handle_get_data",
        fn (uv_handle_ptr) -> UnsafePointer[T],
    ]()(ptr)


fn uv_handle_set_data[T: AnyType](ptr: uv_handle_ptr, data: UnsafePointer[T]):
    return _get_dylib_function[
        "uv_handle_set_data",
        fn (uv_handle_ptr, UnsafePointer[T]),
    ]()(ptr, data)


alias uv_close_cb = fn (uv_handle_ptr) -> None


fn uv_close(handle: uv_handle_ptr, cb: uv_close_cb) -> None:
    return _get_dylib_function[
        "uv_close",
        fn (uv_handle_ptr, uv_close_cb) -> None,
    ]()(handle, cb)


fn uv_ref(handle: uv_handle_ptr) -> None:
    return _get_dylib_function[
        "uv_ref",
        fn (uv_handle_ptr) -> None,
    ]()(handle)


fn uv_unref(handle: uv_handle_ptr) -> None:
    return _get_dylib_function[
        "uv_unref",
        fn (uv_handle_ptr) -> None,
    ]()(handle)


fn uv_has_ref(handle: uv_handle_ptr) -> c_int:
    return _get_dylib_function[
        "uv_has_ref",
        fn (uv_handle_ptr) -> c_int,
    ]()(handle)


fn uv_is_active(handle: uv_handle_ptr) -> c_int:
    return _get_dylib_function[
        "uv_is_active",
        fn (uv_handle_ptr) -> c_int,
    ]()(handle)


fn uv_is_closing(handle: uv_handle_ptr) -> c_int:
    return _get_dylib_function[
        "uv_is_closing",
        fn (uv_handle_ptr) -> c_int,
    ]()(handle)


# TODO: this will only work on unix not windows
fn uv_fileno(handle: uv_handle_ptr, mut fd: UnsafePointer[c_int]) -> c_int:
    return _get_dylib_function[
        "uv_fileno",
        fn (uv_handle_ptr, UnsafePointer[c_int]) -> c_int,
    ]()(handle, fd)


fn uv_handle_get_loop(handle: uv_handle_ptr) -> uv_loop_ptr:
    return _get_dylib_function[
        "uv_handle_get_loop",
        fn (uv_handle_ptr) -> uv_loop_ptr,
    ]()(handle)


@register_passable
struct Handle[type: uv_handle_type](
    Copyable, Movable, EqualityComparable, Stringable
):
    var _ptr: ArcPointer[Ref[uv_handle_t]]

    @staticmethod
    fn new() -> Handle[type]:
        var size = uv_handle_size(type)
        var buf = UnsafePointer[c_char].alloc(size)
        return Handle[type](buf.bitcast[uv_handle_t](), is_owned=True)

    fn __init__(out self, ptr: uv_handle_ptr, is_owned: Bool):
        self._ptr = ArcPointer(Ref(ptr))

    fn __copyinit__(out self, existing: Self):
        self._ptr = existing._ptr

    fn __eq__(self, other: Self) -> Bool:
        return self.unsafe_ptr() == other.unsafe_ptr()

    fn __ne__(self, other: Self) -> Bool:
        return self.unsafe_ptr() != other.unsafe_ptr()

    fn __str__(self) -> String:
        return "handle[" + String(self.unsafe_ptr()) + "]"

    fn unsafe_ptr(self) -> uv_handle_ptr:
        return self._ptr[].ptr

    fn close(self):
        @always_inline
        fn close_cb(handle: uv_handle_ptr):
            pass

        uv_close(self.unsafe_ptr(), close_cb)

    fn has_ref(self) -> Bool:
        return Bool(uv_has_ref(self.unsafe_ptr()))

    fn `ref`(self):
        uv_ref(self.unsafe_ptr())

    fn unref(self):
        uv_unref(self.unsafe_ptr())

    fn is_active(self) -> Bool:
        return Bool(uv_is_active(self.unsafe_ptr()))

    fn is_closing(self) -> Bool:
        return Bool(uv_is_closing(self.unsafe_ptr()))

    fn loop(self) -> Loop:
        var loop = uv_handle_get_loop(self.unsafe_ptr())
        return Loop(loop, is_owned=False)

    fn get_data[T: AnyType](self) -> UnsafePointer[T]:
        return uv_handle_get_data[T](self.unsafe_ptr())

    fn set_data[T: AnyType](self, data: UnsafePointer[T]):
        return uv_handle_set_data(self.unsafe_ptr(), data)


fn uv_idle_init(loop: uv_loop_ptr, idle: uv_handle_ptr) -> c_int:
    return _get_dylib_function[
        "uv_idle_init",
        fn (uv_loop_ptr, uv_handle_ptr) -> c_int,
    ]()(loop, idle)


alias uv_idle_cb = fn (uv_handle_ptr) -> None


fn uv_idle_start(idle: uv_handle_ptr, cb: uv_idle_cb) -> c_int:
    return _get_dylib_function[
        "uv_idle_start",
        fn (uv_handle_ptr, uv_idle_cb) -> c_int,
    ]()(idle, cb)


fn uv_idle_stop(idle: uv_handle_ptr) -> c_int:
    return _get_dylib_function[
        "uv_idle_stop",
        fn (uv_handle_ptr) -> c_int,
    ]()(idle)


struct IdleHandle(Movable):
    var h: Handle[UV_IDLE]
    var idle_func: OwnedPointer[fn () escaping -> Bool]

    @staticmethod
    fn new[func: fn () -> Bool](loop: Loop) -> Self:
        fn wrapper() escaping -> Bool:
            return func()

        return Self(loop, wrapper)

    @staticmethod
    fn new[func: fn () capturing -> Bool](loop: Loop) -> Self:
        fn wrapper() escaping -> Bool:
            return func()

        return Self(loop, wrapper)

    fn __init__(out self, loop: Loop, func: fn () escaping -> Bool):
        self.h = Handle[UV_IDLE].new()
        self.idle_func = OwnedPointer(value=func)
        # always succeeds
        _ = uv_idle_init(loop.unsafe_ptr(), self.h.unsafe_ptr())

    fn __moveinit__(out self, owned existing: Self):
        self.h = existing.h
        self.idle_func = existing.idle_func^

    fn __enter__(owned self) -> Self:
        return self^

    fn __del__(owned self):
        if not self.h.is_closing():
            self.h.close()

    fn start(self):
        # capture unsafe pointer to self
        # to be able to call the idle_func on self
        # this allows capturing / escaping fn to be used
        self_ptr = UnsafePointer(to=self)
        self.h.set_data(self_ptr)

        @always_inline
        fn wrapper(handle: uv_handle_ptr):
            var ptr = uv_handle_get_data[Self](handle)
            is_continue = ptr[].idle_func[]()
            if not is_continue:
                _ = uv_idle_stop(handle)

        _ = uv_idle_start(self.h.unsafe_ptr(), wrapper)

    fn stop(self) raises:
        r = uv_idle_stop(self.h.unsafe_ptr())
        if r != 0:
            raise_uverr["stop failed"](r)


fn uv_timer_init(loop: uv_loop_ptr, timer: uv_handle_ptr) -> c_int:
    return _get_dylib_function[
        "uv_timer_init",
        fn (uv_loop_ptr, uv_handle_ptr) -> c_int,
    ]()(loop, timer)


alias uv_timer_cb = fn (uv_handle_ptr) -> None


fn uv_timer_start(
    timer: uv_handle_ptr,
    cb: uv_timer_cb,
    timeout: c_long_long,
    repeat: c_long_long,
) -> c_int:
    return _get_dylib_function[
        "uv_timer_start",
        fn (uv_handle_ptr, uv_timer_cb, c_long_long, c_long_long) -> c_int,
    ]()(timer, cb, timeout, repeat)


fn uv_timer_stop(timer: uv_handle_ptr) -> c_int:
    return _get_dylib_function[
        "uv_timer_stop",
        fn (uv_handle_ptr) -> c_int,
    ]()(timer)


fn uv_timer_again(timer: uv_handle_ptr) -> c_int:
    return _get_dylib_function[
        "uv_timer_again",
        fn (uv_handle_ptr) -> c_int,
    ]()(timer)


fn uv_timer_get_repeat(timer: uv_handle_ptr) -> c_long_long:
    return _get_dylib_function[
        "uv_timer_get_repeat",
        fn (uv_handle_ptr) -> c_long_long,
    ]()(timer)


fn uv_timer_get_due_in(timer: uv_handle_ptr) -> c_long_long:
    return _get_dylib_function[
        "uv_timer_get_due_in",
        fn (uv_handle_ptr) -> c_long_long,
    ]()(timer)


struct TimerHandle(Movable):
    var h: Handle[UV_TIMER]
    var timer_func: OwnedPointer[fn () escaping -> None]

    @staticmethod
    fn new[func: fn () -> None](loop: Loop) -> Self:
        fn wrapper() escaping -> None:
            return func()

        return Self(loop, wrapper)

    @staticmethod
    fn new[func: fn () capturing -> None](loop: Loop) -> Self:
        fn wrapper() escaping -> None:
            return func()

        return Self(loop, wrapper)

    fn __init__(out self, loop: Loop, func: fn () escaping -> None):
        self.h = Handle[UV_TIMER].new()
        self.timer_func = OwnedPointer(value=func)
        # always succeeds
        _ = uv_timer_init(loop.unsafe_ptr(), self.h.unsafe_ptr())

    # fn __copyinit__(out self, existing: Self):
    #     self.h = existing.h
    #     self.timer_func = OwnedPointer(value=existing.timer_func[])
    #     _ = self.timer_func.take()

    fn __moveinit__(out self, owned existing: Self):
        self.h = existing.h
        self.timer_func = existing.timer_func^

    fn __enter__(owned self) -> Self:
        return self^

    fn __del__(owned self):
        if not self.h.is_closing():
            self.h.close()

    fn start(self, timeout: c_long_long, repeat: c_long_long):
        self_ptr = UnsafePointer(to=self)
        self.h.set_data(self_ptr)

        @always_inline
        fn wrapper(handle: uv_handle_ptr):
            var ptr = uv_handle_get_data[Self](handle)
            ptr[].timer_func[]()

        r = uv_timer_start(self.h.unsafe_ptr(), wrapper, timeout, repeat)
        debug_assert(r == 0)

    fn stop(self) raises:
        r = uv_timer_stop(self.h.unsafe_ptr())
        if r != 0:
            raise_uverr["stop failed"](r)

    fn again(self) raises:
        r = uv_timer_again(self.h.unsafe_ptr())
        if r != 0:
            raise_uverr["again failed"](r)

    fn get_repeat(self) -> c_long_long:
        return uv_timer_get_repeat(self.h.unsafe_ptr())

    fn get_due_in(self) -> c_long_long:
        return uv_timer_get_due_in(self.h.unsafe_ptr())


#
# Prepare
#


fn uv_prepare_init(loop: uv_loop_ptr, prepare: uv_handle_ptr) -> c_int:
    return _get_dylib_function[
        "uv_prepare_init",
        fn (uv_loop_ptr, uv_handle_ptr) -> c_int,
    ]()(loop, prepare)


alias uv_prepare_cb = fn (uv_handle_ptr) -> None


fn uv_prepare_start(prepare: uv_handle_ptr, cb: uv_prepare_cb) -> c_int:
    return _get_dylib_function[
        "uv_prepare_start",
        fn (uv_handle_ptr, uv_prepare_cb) -> c_int,
    ]()(prepare, cb)


fn uv_prepare_stop(prepare: uv_handle_ptr) -> c_int:
    return _get_dylib_function[
        "uv_prepare_stop",
        fn (uv_handle_ptr) -> c_int,
    ]()(prepare)


struct PrepareHandle:
    var h: Handle[UV_PREPARE]

    fn __init__(out self, loop: Loop):
        self.h = Handle[UV_PREPARE].new()
        # always succeeds
        _ = uv_prepare_init(loop._loop, self.h.ptr)

    fn start[func: fn () -> Bool](self):
        @always_inline
        fn wrapper(handle: uv_handle_ptr):
            is_continue = func()
            if not is_continue:
                _ = uv_prepare_stop(handle)

        _ = uv_prepare_start(self.h.ptr, wrapper)

    fn stop(self) raises:
        r = uv_prepare_stop(self.h.ptr)
        if r != 0:
            raise_uverr["stop failed"](r)
