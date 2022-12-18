// Copyright (c) 2022 XXIV
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

// The Wren semantic version number components.
pub const WREN_VERSION_MAJOR = 0;
pub const WREN_VERSION_MINOR = 4;
pub const WREN_VERSION_PATCH = 0;

// A human-friendly string representation of the version.
pub const WREN_VERSION_STRING = "0.4.0";

// A monotonically increasing numeric representation of the version number. Use
// this if you want to do range checks over versions.
pub const WREN_VERSION_NUMBER = WREN_VERSION_MAJOR * 1000000 + WREN_VERSION_MINOR * 1000 + WREN_VERSION_PATCH;

// A single virtual machine for executing Wren code.
//
// Wren has no global state, so all state stored by a running interpreter lives
// here.
pub const WrenVM = opaque {};

// A handle to a Wren object.
//
// This lets code outside of the VM hold a persistent reference to an object.
// After a handle is acquired, and until it is released, this ensures the
// garbage collector will not reclaim the object it references.
pub const WrenHandle = opaque {};

// A generic allocation function that handles all explicit memory management
// used by Wren. It's used like so:
//
// - To allocate new memory, [memory] is NULL and [newSize] is the desired
//   size. It should return the allocated memory or NULL on failure.
//
// - To attempt to grow an existing allocation, [memory] is the memory, and
//   [newSize] is the desired size. It should return [memory] if it was able to
//   grow it in place, or a new pointer if it had to move it.
//
// - To shrink memory, [memory] and [newSize] are the same as above but it will
//   always return [memory].
//
// - To free memory, [memory] will be the memory to free and [newSize] will be
//   zero. It should return NULL.
pub const WrenReallocateFn = ?fn (?*anyopaque, usize, ?*anyopaque) callconv(.C) ?*anyopaque;

// A function callable from Wren code, but implemented in C.
pub const WrenForeignMethodFn = ?fn (?*WrenVM) callconv(.C) void;

// A finalizer function for freeing resources owned by an instance of a foreign
// class. Unlike most foreign methods, finalizers do not have access to the VM
// and should not interact with it since it's in the middle of a garbage
// collection.
pub const WrenFinalizerFn = ?fn (?*anyopaque) callconv(.C) void;

// Gives the host a chance to canonicalize the imported module name,
// potentially taking into account the (previously resolved) name of the module
// that contains the import. Typically, this is used to implement relative
// imports.
pub const WrenResolveModuleFn = ?fn (?*WrenVM, [*c]const u8, [*c]const u8) callconv(.C) [*c]const u8;

// Called after loadModuleFn is called for module [name]. The original returned result
// is handed back to you in this callback, so that you can free memory if appropriate.
pub const WrenLoadModuleCompleteFn = ?fn (?*WrenVM, [*c]const u8, WrenLoadModuleResult) callconv(.C) void;

// The result of a loadModuleFn call.
// [source] is the source code for the module, or NULL if the module is not found.
// [onComplete] an optional callback that will be called once Wren is done with the result.
pub const WrenLoadModuleResult = extern struct {
    source: [*c]const u8,
    onComplete: WrenLoadModuleCompleteFn,
    userData: ?*anyopaque,
};

// Loads and returns the source code for the module [name].
pub const WrenLoadModuleFn = ?fn (?*WrenVM, [*c]const u8) callconv(.C) WrenLoadModuleResult;

// Returns a pointer to a foreign method on [className] in [module] with
// [signature].
pub const WrenBindForeignMethodFn = ?fn (?*WrenVM, [*c]const u8, [*c]const u8, bool, [*c]const u8) callconv(.C) WrenForeignMethodFn;

// Displays a string of text to the user.
pub const WrenWriteFn = ?fn (?*WrenVM, [*c]const u8) callconv(.C) void;

pub const WrenErrorType = enum(c_int) {
    COMPILE,

    // The error message for a runtime error.
    RUNTIME,

    // One entry of a runtime error's stack trace.
    STACK_TRACE,
};

// Reports an error to the user.
//
// An error detected during compile time is reported by calling this once with
// [type] `WREN_ERROR_COMPILE`, the resolved name of the [module] and [line]
// where the error occurs, and the compiler's error [message].
//
// A runtime error is reported by calling this once with [type]
// `WREN_ERROR_RUNTIME`, no [module] or [line], and the runtime error's
// [message]. After that, a series of [type] `WREN_ERROR_STACK_TRACE` calls are
// made for each line in the stack trace. Each of those has the resolved
// [module] and [line] where the method or function is defined and [message] is
// the name of the method or function.
pub const WrenErrorFn = ?fn (?*WrenVM, WrenErrorType, [*c]const u8, c_int, [*c]const u8) callconv(.C) void;

pub const WrenForeignClassMethods = extern struct {

    // The callback invoked when the foreign object is created.
    //
    // This must be provided. Inside the body of this, it must call
    // [wrenSetSlotNewForeign()] exactly once.
    allocate: WrenForeignMethodFn,

    // The callback invoked when the garbage collector is about to collect a
    // foreign object's memory.
    //
    // This may be `NULL` if the foreign class does not need to finalize.
    finalize: WrenFinalizerFn,
};

// Returns a pair of pointers to the foreign methods used to allocate and
// finalize the data for instances of [className] in resolved [module].
pub const WrenBindForeignClassFn = ?fn (?*WrenVM, [*c]const u8, [*c]const u8) callconv(.C) WrenForeignClassMethods;

pub const WrenConfiguration = extern struct {

    // The callback Wren will use to allocate, reallocate, and deallocate memory.
    //
    // If `NULL`, defaults to a built-in function that uses `realloc` and `free`.
    reallocateFn: WrenReallocateFn,

    // The callback Wren uses to resolve a module name.
    //
    // Some host applications may wish to support "relative" imports, where the
    // meaning of an import string depends on the module that contains it. To
    // support that without baking any policy into Wren itself, the VM gives the
    // host a chance to resolve an import string.
    //
    // Before an import is loaded, it calls this, passing in the name of the
    // module that contains the import and the import string. The host app can
    // look at both of those and produce a new "canonical" string that uniquely
    // identifies the module. This string is then used as the name of the module
    // going forward. It is what is passed to [loadModuleFn], how duplicate
    // imports of the same module are detected, and how the module is reported in
    // stack traces.
    //
    // If you leave this function NULL, then the original import string is
    // treated as the resolved string.
    //
    // If an import cannot be resolved by the embedder, it should return NULL and
    // Wren will report that as a runtime error.
    //
    // Wren will take ownership of the string you return and free it for you, so
    // it should be allocated using the same allocation function you provide
    // above.
    resolveModuleFn: WrenResolveModuleFn,

    // The callback Wren uses to load a module.
    //
    // Since Wren does not talk directly to the file system, it relies on the
    // embedder to physically locate and read the source code for a module. The
    // first time an import appears, Wren will call this and pass in the name of
    // the module being imported. The method will return a result, which contains
    // the source code for that module. Memory for the source is owned by the
    // host application, and can be freed using the onComplete callback.
    //
    // This will only be called once for any given module name. Wren caches the
    // result internally so subsequent imports of the same module will use the
    // previous source and not call this.
    //
    // If a module with the given name could not be found by the embedder, it
    // should return NULL and Wren will report that as a runtime error.
    loadModuleFn: WrenLoadModuleFn,

    // The callback Wren uses to find a foreign method and bind it to a class.
    //
    // When a foreign method is declared in a class, this will be called with the
    // foreign method's module, class, and signature when the class body is
    // executed. It should return a pointer to the foreign function that will be
    // bound to that method.
    //
    // If the foreign function could not be found, this should return NULL and
    // Wren will report it as runtime error.
    bindForeignMethodFn: WrenBindForeignMethodFn,

    // The callback Wren uses to find a foreign class and get its foreign methods.
    //
    // When a foreign class is declared, this will be called with the class's
    // module and name when the class body is executed. It should return the
    // foreign functions uses to allocate and (optionally) finalize the bytes
    // stored in the foreign object when an instance is created.
    bindForeignClassFn: WrenBindForeignClassFn,

    // The callback Wren uses to display text when `System.print()` or the other
    // related functions are called.
    //
    // If this is `NULL`, Wren discards any printed text.
    writeFn: WrenWriteFn,

    // The callback Wren uses to report errors.
    //
    // When an error occurs, this will be called with the module name, line
    // number, and an error message. If this is `NULL`, Wren doesn't report any
    // errors.
    errorFn: WrenErrorFn,

    // The number of bytes Wren will allocate before triggering the first garbage
    // collection.
    //
    // If zero, defaults to 10MB.
    initialHeapSize: usize,

    // After a collection occurs, the threshold for the next collection is
    // determined based on the number of bytes remaining in use. This allows Wren
    // to shrink its memory usage automatically after reclaiming a large amount
    // of memory.
    //
    // This can be used to ensure that the heap does not get too small, which can
    // in turn lead to a large number of collections afterwards as the heap grows
    // back to a usable size.
    //
    // If zero, defaults to 1MB.
    minHeapSize: usize,

    // Wren will resize the heap automatically as the number of bytes
    // remaining in use after a collection changes. This number determines the
    // amount of additional memory Wren will use after a collection, as a
    // percentage of the current heap size.
    //
    // For example, say that this is 50. After a garbage collection, when there
    // are 400 bytes of memory still in use, the next collection will be triggered
    // after a total of 600 bytes are allocated (including the 400 already in
    // use.)
    //
    // Setting this to a smaller number wastes less memory, but triggers more
    // frequent garbage collections.
    //
    // If zero, defaults to 50.
    heapGrowthPercent: c_int,

    // User-defined data associated with the VM.
    userData: ?*anyopaque,
};
pub const WrenInterpretResult = enum(c_int) { SUCCESS, COMPILE_ERROR, RUNTIME_ERROR };

// The type of an object stored in a slot.
//
// This is not necessarily the object's *class*, but instead its low level
// representation type.
pub const WrenType = enum(c_int) {
    BOOL,
    NUM,
    FOREIGN,
    LIST,
    MAP,
    NULL,
    STRING,

    // The object is of a type that isn't accessible by the C API.
    UNKNOWN,
};

// Get the current wren version number.
//
// Can be used to range checks over versions.
pub extern "C" fn wrenGetVersionNumber() c_int;

// Initializes [configuration] with all of its default values.
//
// Call this before setting the particular fields you care about.
pub extern "C" fn wrenInitConfiguration(configuration: [*c]WrenConfiguration) void;

// Creates a new Wren virtual machine using the given [configuration]. Wren
// will copy the configuration data, so the argument passed to this can be
// freed after calling this. If [configuration] is `NULL`, uses a default
// configuration.
pub extern "C" fn wrenNewVM(configuration: [*c]WrenConfiguration) ?*WrenVM;

// Disposes of all resources is use by [vm], which was previously created by a
// call to [wrenNewVM].
pub extern "C" fn wrenFreeVM(vm: ?*WrenVM) void;

// Immediately run the garbage collector to free unused memory.
pub extern "C" fn wrenCollectGarbage(vm: ?*WrenVM) void;

// Runs [source], a string of Wren source code in a new fiber in [vm] in the
// context of resolved [module].
pub extern "C" fn wrenInterpret(vm: ?*WrenVM, module: [*c]const u8, source: [*c]const u8) WrenInterpretResult;

// Creates a handle that can be used to invoke a method with [signature] on
// using a receiver and arguments that are set up on the stack.
//
// This handle can be used repeatedly to directly invoke that method from C
// code using [wrenCall].
//
// When you are done with this handle, it must be released using
// [wrenReleaseHandle].
pub extern "C" fn wrenMakeCallHandle(vm: ?*WrenVM, signature: [*c]const u8) ?*WrenHandle;

// Calls [method], using the receiver and arguments previously set up on the
// stack.
//
// [method] must have been created by a call to [wrenMakeCallHandle]. The
// arguments to the method must be already on the stack. The receiver should be
// in slot 0 with the remaining arguments following it, in order. It is an
// error if the number of arguments provided does not match the method's
// signature.
//
// After this returns, you can access the return value from slot 0 on the stack.
pub extern "C" fn wrenCall(vm: ?*WrenVM, method: ?*WrenHandle) WrenInterpretResult;

// Releases the reference stored in [handle]. After calling this, [handle] can
// no longer be used.
pub extern "C" fn wrenReleaseHandle(vm: ?*WrenVM, handle: ?*WrenHandle) void;

// The following functions are intended to be called from foreign methods or
// finalizers. The interface Wren provides to a foreign method is like a
// register machine: you are given a numbered array of slots that values can be
// read from and written to. Values always live in a slot (unless explicitly
// captured using wrenGetSlotHandle(), which ensures the garbage collector can
// find them.
//
// When your foreign function is called, you are given one slot for the receiver
// and each argument to the method. The receiver is in slot 0 and the arguments
// are in increasingly numbered slots after that. You are free to read and
// write to those slots as you want. If you want more slots to use as scratch
// space, you can call wrenEnsureSlots() to add more.
//
// When your function returns, every slot except slot zero is discarded and the
// value in slot zero is used as the return value of the method. If you don't
// store a return value in that slot yourself, it will retain its previous
// value, the receiver.
//
// While Wren is dynamically typed, C is not. This means the C interface has to
// support the various types of primitive values a Wren variable can hold: bool,
// double, string, etc. If we supported this for every operation in the C API,
// there would be a combinatorial explosion of functions, like "get a
// double-valued element from a list", "insert a string key and double value
// into a map", etc.
//
// To avoid that, the only way to convert to and from a raw C value is by going
// into and out of a slot. All other functions work with values already in a
// slot. So, to add an element to a list, you put the list in one slot, and the
// element in another. Then there is a single API function wrenInsertInList()
// that takes the element out of that slot and puts it into the list.
//
// The goal of this API is to be easy to use while not compromising performance.
// The latter means it does not do type or bounds checking at runtime except
// using assertions which are generally removed from release builds. C is an
// unsafe language, so it's up to you to be careful to use it correctly. In
// return, you get a very fast FFI.

// Returns the number of slots available to the current foreign method.
pub extern "C" fn wrenGetSlotCount(vm: ?*WrenVM) c_int;

// Ensures that the foreign method stack has at least [numSlots] available for
// use, growing the stack if needed.
//
// Does not shrink the stack if it has more than enough slots.
//
// It is an error to call this from a finalizer.
pub extern "C" fn wrenEnsureSlots(vm: ?*WrenVM, numSlots: c_int) void;

// Gets the type of the object in [slot].
pub extern "C" fn wrenGetSlotType(vm: ?*WrenVM, slot: c_int) WrenType;

// Reads a boolean value from [slot].
//
// It is an error to call this if the slot does not contain a boolean value.
pub extern "C" fn wrenGetSlotBool(vm: ?*WrenVM, slot: c_int) bool;

// Reads a byte array from [slot].
//
// The memory for the returned string is owned by Wren. You can inspect it
// while in your foreign method, but cannot keep a pointer to it after the
// function returns, since the garbage collector may reclaim it.
//
// Returns a pointer to the first byte of the array and fill [length] with the
// number of bytes in the array.
//
// It is an error to call this if the slot does not contain a string.
pub extern "C" fn wrenGetSlotBytes(vm: ?*WrenVM, slot: c_int, length: [*c]c_int) [*c]const u8;

// Reads a number from [slot].
//
// It is an error to call this if the slot does not contain a number.
pub extern "C" fn wrenGetSlotDouble(vm: ?*WrenVM, slot: c_int) f64;

// Reads a foreign object from [slot] and returns a pointer to the foreign data
// stored with it.
//
// It is an error to call this if the slot does not contain an instance of a
// foreign class.
pub extern "C" fn wrenGetSlotForeign(vm: ?*WrenVM, slot: c_int) ?*anyopaque;

// Reads a string from [slot].
//
// The memory for the returned string is owned by Wren. You can inspect it
// while in your foreign method, but cannot keep a pointer to it after the
// function returns, since the garbage collector may reclaim it.
//
// It is an error to call this if the slot does not contain a string.
pub extern "C" fn wrenGetSlotString(vm: ?*WrenVM, slot: c_int) [*c]const u8;

// Creates a handle for the value stored in [slot].
//
// This will prevent the object that is referred to from being garbage collected
// until the handle is released by calling [wrenReleaseHandle()].
pub extern "C" fn wrenGetSlotHandle(vm: ?*WrenVM, slot: c_int) ?*WrenHandle;

// Stores the boolean [value] in [slot].
pub extern "C" fn wrenSetSlotBool(vm: ?*WrenVM, slot: c_int, value: bool) void;

// Stores the array [length] of [bytes] in [slot].
//
// The bytes are copied to a new string within Wren's heap, so you can free
// memory used by them after this is called.
pub extern "C" fn wrenSetSlotBytes(vm: ?*WrenVM, slot: c_int, bytes: [*c]const u8, length: usize) void;

// Stores the numeric [value] in [slot].
pub extern "C" fn wrenSetSlotDouble(vm: ?*WrenVM, slot: c_int, value: f64) void;

// Creates a new instance of the foreign class stored in [classSlot] with [size]
// bytes of raw storage and places the resulting object in [slot].
//
// This does not invoke the foreign class's constructor on the new instance. If
// you need that to happen, call the constructor from Wren, which will then
// call the allocator foreign method. In there, call this to create the object
// and then the constructor will be invoked when the allocator returns.
//
// Returns a pointer to the foreign object's data.
pub extern "C" fn wrenSetSlotNewForeign(vm: ?*WrenVM, slot: c_int, classSlot: c_int, size: usize) ?*anyopaque;

// Stores a new empty list in [slot].
pub extern "C" fn wrenSetSlotNewList(vm: ?*WrenVM, slot: c_int) void;

// Stores a new empty map in [slot].
pub extern "C" fn wrenSetSlotNewMap(vm: ?*WrenVM, slot: c_int) void;

// Stores null in [slot].
pub extern "C" fn wrenSetSlotNull(vm: ?*WrenVM, slot: c_int) void;

// Stores the string [text] in [slot].
//
// The [text] is copied to a new string within Wren's heap, so you can free
// memory used by it after this is called. The length is calculated using
// [strlen()]. If the string may contain any null bytes in the middle, then you
// should use [wrenSetSlotBytes()] instead.
pub extern "C" fn wrenSetSlotString(vm: ?*WrenVM, slot: c_int, text: [*c]const u8) void;

// Stores the value captured in [handle] in [slot].
//
// This does not release the handle for the value.
pub extern "C" fn wrenSetSlotHandle(vm: ?*WrenVM, slot: c_int, handle: ?*WrenHandle) void;

// Returns the number of elements in the list stored in [slot].
pub extern "C" fn wrenGetListCount(vm: ?*WrenVM, slot: c_int) c_int;

// Reads element [index] from the list in [listSlot] and stores it in
// [elementSlot].
pub extern "C" fn wrenGetListElement(vm: ?*WrenVM, listSlot: c_int, index: c_int, elementSlot: c_int) void;

// Sets the value stored at [index] in the list at [listSlot],
// to the value from [elementSlot].
pub extern "C" fn wrenSetListElement(vm: ?*WrenVM, listSlot: c_int, index: c_int, elementSlot: c_int) void;

// Takes the value stored at [elementSlot] and inserts it into the list stored
// at [listSlot] at [index].
//
// As in Wren, negative indexes can be used to insert from the end. To append
// an element, use `-1` for the index.
pub extern "C" fn wrenInsertInList(vm: ?*WrenVM, listSlot: c_int, index: c_int, elementSlot: c_int) void;

// Returns the number of entries in the map stored in [slot].
pub extern "C" fn wrenGetMapCount(vm: ?*WrenVM, slot: c_int) c_int;

// Returns true if the key in [keySlot] is found in the map placed in [mapSlot].
pub extern "C" fn wrenGetMapContainsKey(vm: ?*WrenVM, mapSlot: c_int, keySlot: c_int) bool;

// Retrieves a value with the key in [keySlot] from the map in [mapSlot] and
// stores it in [valueSlot].
pub extern "C" fn wrenGetMapValue(vm: ?*WrenVM, mapSlot: c_int, keySlot: c_int, valueSlot: c_int) void;

// Takes the value stored at [valueSlot] and inserts it into the map stored
// at [mapSlot] with key [keySlot].
pub extern "C" fn wrenSetMapValue(vm: ?*WrenVM, mapSlot: c_int, keySlot: c_int, valueSlot: c_int) void;

// Removes a value from the map in [mapSlot], with the key from [keySlot],
// and place it in [removedValueSlot]. If not found, [removedValueSlot] is
// set to null, the same behaviour as the Wren Map API.
pub extern "C" fn wrenRemoveMapValue(vm: ?*WrenVM, mapSlot: c_int, keySlot: c_int, removedValueSlot: c_int) void;

// Looks up the top level variable with [name] in resolved [module] and stores
// it in [slot].
pub extern "C" fn wrenGetVariable(vm: ?*WrenVM, module: [*c]const u8, name: [*c]const u8, slot: c_int) void;

// Looks up the top level variable with [name] in resolved [module],
// returns false if not found. The module must be imported at the time,
// use wrenHasModule to ensure that before calling.
pub extern "C" fn wrenHasVariable(vm: ?*WrenVM, module: [*c]const u8, name: [*c]const u8) bool;

// Returns true if [module] has been imported/resolved before, false if not.
pub extern "C" fn wrenHasModule(vm: ?*WrenVM, module: [*c]const u8) bool;

// Sets the current fiber to be aborted, and uses the value in [slot] as the
// runtime error object.
pub extern "C" fn wrenAbortFiber(vm: ?*WrenVM, slot: c_int) void;

// Returns the user data associated with the WrenVM.
pub extern "C" fn wrenGetUserData(vm: ?*WrenVM) ?*anyopaque;

// Sets user data associated with the WrenVM.
pub extern "C" fn wrenSetUserData(vm: ?*WrenVM, userData: ?*anyopaque) void;
