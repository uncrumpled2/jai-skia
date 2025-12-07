// skia_ref_helper.cpp
// Helper to expose SkRefCntBase::ref() and unref() which are inlined in Skia headers
// and not exported from the Skia shared library.
//
// SkRefCntBase memory layout (x86-64):
//   - vtable pointer (8 bytes at offset 0)
//   - fRefCnt: std::atomic<int32_t> (4 bytes at offset 8)
//
// This allows Jai code to properly manage reference counts for sk_sp<T> types
// without calling the inlined C++ functions directly.

#include <cstdint>
#include <atomic>

// Platform-specific export macro
#ifdef _WIN32
    #define SK_HELPER_EXPORT __declspec(dllexport)
#else
    #define SK_HELPER_EXPORT __attribute__((visibility("default")))
#endif

extern "C" {
    // Increment the reference count of an SkRefCntBase-derived object
    SK_HELPER_EXPORT void sk_ref_cnt_ref(void* ptr) {
        if (ptr) {
            // refcount is at offset 8 (after vtable pointer)
            std::atomic<int32_t>* refcnt = reinterpret_cast<std::atomic<int32_t>*>(
                static_cast<char*>(ptr) + 8
            );
            refcnt->fetch_add(1, std::memory_order_relaxed);
        }
    }

    // Decrement the reference count of an SkRefCntBase-derived object
    // If the count reaches 0, calls the destructor through the vtable
    SK_HELPER_EXPORT void sk_ref_cnt_unref(void* ptr) {
        if (ptr) {
            std::atomic<int32_t>* refcnt = reinterpret_cast<std::atomic<int32_t>*>(
                static_cast<char*>(ptr) + 8
            );
            if (refcnt->fetch_sub(1, std::memory_order_acq_rel) == 1) {
                // Count was 1, now 0 - call destructor through vtable
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
    SK_HELPER_EXPORT int32_t sk_ref_cnt_get_count(void* ptr) {
        if (ptr) {
            std::atomic<int32_t>* refcnt = reinterpret_cast<std::atomic<int32_t>*>(
                static_cast<char*>(ptr) + 8
            );
            return refcnt->load(std::memory_order_relaxed);
        }
        return -1;
    }
}
