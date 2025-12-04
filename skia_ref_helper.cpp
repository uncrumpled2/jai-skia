// skia_ref_helper.cpp
// Helper to expose SkRefCntBase::ref() and unref() which are inlined in Skia headers
// and not exported from libskia.so.
//
// SkRefCntBase memory layout (x86-64):
//   - vtable pointer (8 bytes at offset 0)
//   - fRefCnt: std::atomic<int32_t> (4 bytes at offset 8)
//
// This allows Jai code to properly manage reference counts for sk_sp<T> types
// without calling the inlined C++ functions directly.

#include <cstdint>

extern "C" {
    // Increment the reference count of an SkRefCntBase-derived object
    void sk_ref_cnt_ref(void* ptr) {
        if (ptr) {
            // refcount is at offset 8 (after vtable pointer)
            int32_t* refcnt = reinterpret_cast<int32_t*>(static_cast<char*>(ptr) + 8);
            __atomic_add_fetch(refcnt, 1, __ATOMIC_RELAXED);
        }
    }

    // Decrement the reference count of an SkRefCntBase-derived object
    // If the count reaches 0, calls the destructor through the vtable
    void sk_ref_cnt_unref(void* ptr) {
        if (ptr) {
            int32_t* refcnt = reinterpret_cast<int32_t*>(static_cast<char*>(ptr) + 8);
            if (__atomic_sub_fetch(refcnt, 1, __ATOMIC_ACQ_REL) == 0) {
                // Call destructor through vtable
                // The vtable layout for SkRefCntBase:
                //   [0] = Destructor (D1 - complete object destructor)
                //   [1] = Destructor_Deleting (D0 - deleting destructor)
                //   [2] = internal_dispose
                // We call internal_dispose which handles cleanup properly
                void** vtable = *reinterpret_cast<void***>(ptr);
                typedef void (*dispose_fn)(const void*);
                // internal_dispose is at index 2 in the vtable
                dispose_fn dispose = reinterpret_cast<dispose_fn>(vtable[2]);
                dispose(ptr);
            }
        }
    }

    // Get the current reference count (for debugging)
    int32_t sk_ref_cnt_get_count(void* ptr) {
        if (ptr) {
            int32_t* refcnt = reinterpret_cast<int32_t*>(static_cast<char*>(ptr) + 8);
            return __atomic_load_n(refcnt, __ATOMIC_RELAXED);
        }
        return -1;
    }
}
