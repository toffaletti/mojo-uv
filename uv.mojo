from memory import UnsafePointer, stack_allocation
from pathlib import Path
from utils import Variant
from sys.ffi import (
    c_char,
    c_int,
    c_uint,
    c_size_t,
)
from sys.ffi import _get_dylib_function as _ffi_get_dylib_function
from sys.ffi import _Global, _OwnedDLHandle, _find_dylib

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


struct Loop[is_owned: Bool = False]:
    var _loop: uv_loop_ptr

    @staticmethod
    fn default() -> Loop[False]:
        return Loop[False](uv_default_loop())

    @staticmethod
    fn new() raises -> Loop[True]:
        var size = uv_loop_size()
        var buf = UnsafePointer[c_char].alloc(size)
        loop = Loop[True](buf.bitcast[uv_loop_t]())
        r = uv_loop_init(loop._loop)
        if r != 0:
            raise_uverr["init failed"](r)
        return loop^

    fn __init__(out self, loop: uv_loop_ptr):
        self._loop = loop

    fn __copyinit__(out self, existing: Self):
        self._loop = existing._loop

    fn __moveinit__(out self, owned existing: Self):
        self._loop = existing._loop

    fn __del__(owned self):
        if is_owned:
            self._loop.free()

    fn __enter__(self) -> Self:
        return self

    fn __exit__(self) raises:
        print("exiting")
        self.close()

    fn close(self) raises:
        print("closing:", self._loop)
        r = uv_loop_close(self._loop)
        if r != 0:
            raise_uverr["close failed"](r)

    fn run(self, mode: uv_run_mode = UV_RUN_DEFAULT) -> Int:
        return Int(uv_run(self._loop, mode))

    fn alive(self) -> Bool:
        return Bool(uv_loop_alive(self._loop))

    fn get_data[T: AnyType](self) -> UnsafePointer[T]:
        return uv_loop_get_data[T](self._loop)

    fn set_data[T: AnyType](self, data: UnsafePointer[T]):
        return uv_loop_set_data(self._loop, data)


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


alias uv_close_cb = fn (uv_handle_ptr) -> None


fn uv_handle_close(handle: uv_handle_ptr, cb: uv_close_cb) -> None:
    return _get_dylib_function[
        "uv_handle_get_type",
        fn (uv_handle_ptr, uv_close_cb) -> None,
    ]()(handle, cb)


struct Handle[type: uv_handle_type]:
    var ptr: uv_handle_ptr

    @staticmethod
    fn new() -> Handle[type]:
        var size = uv_handle_size(type)
        var buf = UnsafePointer[c_char].alloc(size)
        return Handle[type](buf.bitcast[uv_handle_t]())

    fn __init__(out self, ptr: uv_handle_ptr):
        self.ptr = ptr

    fn __del__(owned self):
        print("freeing:", self.ptr)
        self.ptr.free()

    fn close(self):
        @always_inline
        fn close_cb(handle: uv_handle_ptr):
            print("closed:", handle)
            pass

        print("closing:", self.ptr)
        uv_handle_close(self.ptr, close_cb)


struct IdleHandle:
    var h: Handle[UV_IDLE]

    fn __init__(out self, loop: Loop) raises:
        self.h = Handle[UV_IDLE].new()
        r = uv_idle_init(loop._loop, self.h.ptr)
        if r != 0:
            raise_uverr["init failed"](r)

    fn start[func: fn () -> Bool](self):
        @always_inline
        fn wrapper(handle: uv_handle_ptr):
            is_continue = func()
            if not is_continue:
                _ = uv_idle_stop(handle)

        _ = uv_idle_start(self.h.ptr, wrapper)

    fn stop(self) raises:
        r = uv_idle_stop(self.h.ptr)
        if r != 0:
            raise_uverr["stop failed"](r)


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


# fn uv_loop_init(
#     light_handle: UnsafePointer[UnsafePointer[Context]],
# ) -> Result:
#     return _get_dylib_function[
#         "cublasLtCreate",
#         fn (UnsafePointer[UnsafePointer[Context]]) -> Result,
#     ]()(light_handle)


# fn main() raises:
#     alias py = Python()
#     var d = py.dict()
#     d["a"] = "b"
#     print(d.__str__())
#     var h = ffi.DLHandle("/usr/lib/libSystem.B.dylib")
#     if not h.check_symbol("gethostname"):
#         print("no gethostname")
#         return
#     var name = SIMD[DType.int8, 512]()
#     var ptr = stack_allocation[512, ffi.c_char]()
#     var r = h.call[
#         "gethostname", ffi.c_int, UnsafePointer[ffi.c_char], ffi.c_size_t
#     ](ptr, 512)
#     print("result:", r)
#     if r != 0:
#         return
#     hname = StringSlice[origin = ptr.origin](unsafe_from_utf8_ptr=ptr)
#     print("hostname:", hname)
