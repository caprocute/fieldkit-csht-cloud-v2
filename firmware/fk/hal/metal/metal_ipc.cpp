#include <os.h>

#include "hal/hal.h"
#include "hal/metal/metal.h"

#include "tasks/tasks.h"

#if defined(__SAMD51__)

namespace fk {

FK_DECLARE_LOGGER("ipc");

MetalMutex workers_mutex{ "workers" };
MetalMutex storage_mutex{ "storage" };
MetalMutex modules_mutex{ "modules" };
MetalMutex sd_mutex{ "sd" };
MetalMutex i2c_module_mutex{ "i2c-module" };
MetalMutex i2c_core_mutex{ "i2c-core" };
MetalMutex i2c_radio_mutex{ "i2c-radio" };
MetalMutex lora_mutex{ "lora" };
MetalRwLock data_lock;
NoopMutex wifi_mutex;

os_queue_define(activity_queue, 10, sizeof(Activity *), OS_QUEUE_FLAGS_QUEUE_ONLY);
os_queue_define(button_queue, 10, sizeof(Button *), OS_QUEUE_FLAGS_NONE);
os_queue_define(topology_queue, 10, sizeof(Activity *), OS_QUEUE_FLAGS_QUEUE_ONLY);

MetalIPC::MetalIPC() {
    for (auto i = 0u; i < NumberOfWorkerTasks; ++i) {
        running_[i] = WorkerCategory::None;
        started_[i] = 0;
        workers_[i] = nullptr;
    }
}

bool MetalIPC::available() {
    return os_is_running();
}

bool MetalIPC::begin() {
    OS_CHECK(os_queue_create(os_queue(activity_queue), os_queue_def(activity_queue)));
    OS_CHECK(os_queue_create(os_queue(button_queue), os_queue_def(button_queue)));
    OS_CHECK(os_queue_create(os_queue(topology_queue), os_queue_def(topology_queue)));

    FK_ASSERT(storage_mutex.create());
    FK_ASSERT(modules_mutex.create());
    FK_ASSERT(workers_mutex.create());
    FK_ASSERT(sd_mutex.create());
    FK_ASSERT(wifi_mutex.create());
    FK_ASSERT(i2c_module_mutex.create());
    FK_ASSERT(i2c_core_mutex.create());
    FK_ASSERT(i2c_radio_mutex.create());
    FK_ASSERT(lora_mutex.create());
    FK_ASSERT(data_lock.create());

    return true;
}

bool MetalIPC::enqueue_activity(Activity *ptr) {
    auto tuple = os_queue_enqueue(os_queue(activity_queue), &ptr, 0);
    return tuple.status == OSS_SUCCESS;
}

bool MetalIPC::dequeue_activity(Activity **ptr, uint32_t to) {
    auto tuple = os_queue_dequeue(os_queue(activity_queue), to);
    if (tuple.status != OSS_SUCCESS) {
        return false;
    }
    *ptr = reinterpret_cast<Activity *>(tuple.value.ptr);
    return true;
}

bool MetalIPC::enqueue_button_down(Button *ptr) {
    if (fk_debug_mode() != nullptr) {
        return true;
    }
    return os_queue_enqueue_isr(os_queue(activity_queue), &ptr) == OSS_SUCCESS;
}

bool MetalIPC::enqueue_button_up(Button *ptr) {
    return os_queue_enqueue_isr(os_queue(button_queue), &ptr) == OSS_SUCCESS;
}

bool MetalIPC::dequeue_button(Button **ptr, uint32_t to) {
    auto tuple = os_queue_dequeue(os_queue(button_queue), to);
    if (tuple.status != OSS_SUCCESS) {
        return false;
    }
    *ptr = reinterpret_cast<Button *>(tuple.value.ptr);
    return true;
}

bool MetalIPC::enqueue_topology(Activity *ptr) {
    auto tuple = os_queue_enqueue(os_queue(topology_queue), &ptr, 0);
    return tuple.status == OSS_SUCCESS;
}

bool MetalIPC::dequeue_topology(Activity **ptr, uint32_t to) {
    auto tuple = os_queue_dequeue(os_queue(topology_queue), to);
    if (tuple.status != OSS_SUCCESS) {
        return false;
    }
    *ptr = reinterpret_cast<Activity *>(tuple.value.ptr);
    return true;
}

bool MetalIPC::can_launch(WorkerCategory category, Lock & /*required_lock*/) {
    if (category == WorkerCategory::None) {
        return true;
    }

    for (auto i = 0u; i < NumberOfWorkerTasks; ++i) {
        if (os_task_is_running(&worker_tasks[i])) {
            if (running_[i] == category) {
                return false;
            }
        }
    }

    return true;
}

bool MetalIPC::launch_worker(WorkerCategory category, TaskWorker *worker, bool concurrency_allowed) {
    auto lock = workers_mutex.acquire(UINT32_MAX);
    FK_ASSERT(lock);

    if (!concurrency_allowed && !can_launch(category, lock)) {
        logwarn("unable to launch %s, already running", worker->name());
        delete worker;
        return false;
    }

    for (auto i = 0u; i < NumberOfWorkerTasks; ++i) {
        if (!os_task_is_running(&worker_tasks[i])) {
            os_task_set_name(&worker_tasks[i], worker->name());
            running_[i] = category;
            workers_[i] = worker;
            started_[i] = fk_uptime();

            auto priority = worker->priority();
            OS_CHECK(os_task_start_options(&worker_tasks[i], priority, worker));

            return true;
        }
    }

    logwarn("all workers are busy");
    delete worker;
    return false;
}

bool MetalIPC::fork_worker(WorkerCategory category, TaskWorker *worker) {
    worker->run();

    return true;
}

bool MetalIPC::remove_worker(TaskWorker *worker) {
    auto lock = workers_mutex.acquire(UINT32_MAX);
    FK_ASSERT(lock);

    for (auto i = 0u; i < NumberOfWorkerTasks; ++i) {
        if (workers_[i] == worker) {
            workers_[i] = nullptr;
            started_[i] = 0;
            return true;
        }
    }

    return false;
}

bool MetalIPC::signal_workers(WorkerCategory category, uint32_t signal) {
    auto lock = workers_mutex.acquire(UINT32_MAX);
    FK_ASSERT(lock);

    logdebug("signaling workers (%" PRIu32 ")", signal);

    for (auto i = 0u; i < NumberOfWorkerTasks; ++i) {
        if (os_task_is_running(&worker_tasks[i])) {
            if (running_[i] == category) {
                loginfo("signaling worker %zd (%" PRIu32 ")", i, signal);
                os_task_stop(&worker_tasks[i]);
            }
        }
    }

    return true;
}

collection<TaskDisplayInfo> MetalIPC::get_workers_display_info(Pool &pool) {
    auto lock = workers_mutex.acquire(UINT32_MAX);
    FK_ASSERT(lock);

    collection<TaskDisplayInfo> infos{ pool };

    for (auto i = 0u; i < NumberOfWorkerTasks; ++i) {
        if (os_task_is_running(&worker_tasks[i])) {
            if (workers_[i] != nullptr) {
                FK_ASSERT_ADDRESS(workers_[i]);
                infos.emplace(workers_[i]->display_info());
            }
        }
    }

    return infos;
}

bool MetalIPC::has_running_worker(WorkerCategory category) {
    auto lock = workers_mutex.acquire(UINT32_MAX);
    FK_ASSERT(lock);

    auto found = false;

    for (auto i = 0u; i < NumberOfWorkerTasks; ++i) {
        if (os_task_is_running(&worker_tasks[i])) {
            if (running_[i] == category) {
                found = true;
                break;
            }
        }
    }

    return found;
}

bool MetalIPC::has_stalled_workers(WorkerCategory category, uint32_t stall_ms) {
    auto lock = workers_mutex.acquire(UINT32_MAX);
    FK_ASSERT(lock);

    auto now = fk_uptime();

    for (auto i = 0u; i < NumberOfWorkerTasks; ++i) {
        if (os_task_is_running(&worker_tasks[i])) {
            if (running_[i] == category) {
                if (now == started_[i] || started_[i] == 0) {
                    continue;
                }
                if (now > started_[i]) {
                    auto elapsed = now - started_[i];
                    if (elapsed > stall_ms) {
                        loginfo("elapsed = %" PRIu32 " started = %" PRIu32, elapsed, started_[i]);
                        return true;
                    }
                } else if (started_[i] > 0) {
                    logwarn("worker started in the future: %" PRIu32 " vs %" PRIu32, now, started_[i]);
                } else {
                    logwarn("worker started wrong: %" PRIu32 " vs %" PRIu32, now, started_[i]);
                }
            }
        }
    }

    return false;
}

bool MetalIPC::has_any_running_worker() {
    auto lock = workers_mutex.acquire(UINT32_MAX);
    FK_ASSERT(lock);

    auto found = false;

    for (auto i = 0u; i < NumberOfWorkerTasks; ++i) {
        if (os_task_is_running(&worker_tasks[i])) {
            found = true;
            break;
        }
    }

    return found;
}

void MetalIPC::verify() {
    for (auto i = 0u; i < NumberOfWorkerTasks; ++i) {
        if (workers_[i] != nullptr) {
            FK_ASSERT_ADDRESS(workers_[i]);
        }
    }
}

bool MetalMutex::create() {
    return os_mutex_create(&mutex_, &def_) == OSS_SUCCESS;
}

Lock MetalMutex::acquire(uint32_t to) {
    if (!os_is_running()) {
        return Lock{ true, this };
    }
#if defined(FK_DEBUG_LOCKS_ACQUIRE)
    auto started = fk_uptime();
#endif
    if (os_mutex_acquire(&mutex_, to) == OSS_SUCCESS) {
#if defined(FK_DEBUG_LOCKS_ACQUIRE)
        auto elapsed = fk_uptime() - started;
        if (elapsed > FK_DEBUG_LOCKS_ACQUIRE) {
            logwarn("%s acquire: %dms", name_, elapsed);
        }
#endif
        return Lock{ true, this };
    }
    return Lock{ false, nullptr };
}

bool MetalMutex::release(uint32_t elapsed, bool exclusive) {
    FK_ASSERT(exclusive);

    if (!os_is_running()) {
        return true;
    }
#if defined(FK_DEBUG_LOCKS_HELD)
    if (elapsed > FK_DEBUG_LOCKS_HELD) {
        logwarn("%s held: %dms", name_, elapsed);
    }
#endif
    os_mutex_release(&mutex_);
    return true;
}

bool MetalRwLock::create() {
    return os_rwlock_create(&rwlock_, &def_) == OSS_SUCCESS;
}

Lock MetalRwLock::acquire_read(uint32_t to) {
    if (!os_is_running()) {
        return Lock{ false, this };
    }
#if defined(FK_DEBUG_LOCKS_ACQUIRE)
    auto started = fk_uptime();
#endif
    if (os_rwlock_acquire_read(&rwlock_, to) == OSS_SUCCESS) {
#if defined(FK_DEBUG_LOCKS_ACQUIRE)
        auto elapsed = fk_uptime() - started;
        if (elapsed > FK_DEBUG_LOCKS_ACQUIRE) {
            logwarn("acquire read: %dms", elapsed);
        }
#endif
        return Lock{ false, this };
    }
    return Lock{ false, nullptr };
}

Lock MetalRwLock::acquire_write(uint32_t to) {
    if (!os_is_running()) {
        return Lock{ true, this };
    }
#if defined(FK_DEBUG_LOCKS_ACQUIRE)
    auto started = fk_uptime();
#endif
    if (os_rwlock_acquire_write(&rwlock_, to) == OSS_SUCCESS) {
#if defined(FK_DEBUG_LOCKS_ACQUIRE)
        auto elapsed = fk_uptime() - started;
        if (elapsed > FK_DEBUG_LOCKS_ACQUIRE) {
            logwarn("acquire write: %dms", elapsed);
        }
#endif
        return Lock{ true, this };
    }
    return Lock{ false, nullptr };
}

bool MetalRwLock::release(uint32_t elapsed, bool exclusive) {
    if (!os_is_running()) {
        return true;
    }
    if (exclusive) {
#if defined(FK_DEBUG_LOCKS_HELD)
        if (elapsed > FK_DEBUG_LOCKS_HELD) {
            logwarn("write held: %dms", elapsed);
        }
#endif
        return os_rwlock_release_write(&rwlock_) == OSS_SUCCESS;
    } else {
#if defined(FK_DEBUG_LOCKS_HELD)
        if (elapsed > FK_DEBUG_LOCKS_HELD) {
            logwarn("read held: %dms", elapsed);
        }
#endif
        return os_rwlock_release_read(&rwlock_) == OSS_SUCCESS;
    }
}

} // namespace fk

#endif
