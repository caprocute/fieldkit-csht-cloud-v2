<template>
    <StandardLayout>
        <div class="admin-moderation">
            <h1>{{ $t("admin.moderationList.title") }}</h1>

            <div v-if="busy" class="loading-container">{{ $t("admin.moderationList.loading") }}</div>

            <div v-else-if="moderationRequests.length === 0" class="empty-state">
                <p>{{ $t("admin.moderationList.noModerationRequests") }}</p>
            </div>

            <div v-else class="table-responsive">
                <table class="moderation-table">
                    <thead>
                        <tr>
                            <th>{{ $t("admin.moderationList.id") }}</th>
                            <th>{{ $t("admin.moderationList.postId") }}</th>
                            <th>{{ $t("admin.moderationList.type") }}</th>
                            <th>{{ $t("admin.moderationList.reportedBy") }}</th>
                            <th>{{ $t("admin.moderationList.reportedAt") }}</th>
                            <th>{{ $t("admin.moderationList.status") }}</th>
                            <th>{{ $t("admin.moderationList.acknowledgedBy") }}</th>
                            <th>{{ $t("admin.moderationList.actions") }}</th>
                        </tr>
                    </thead>
                    <tbody>
                        <tr v-for="request in moderationRequests" :key="request.id">
                            <td data-label="ID">{{ request.id }}</td>
                            <td data-label="Post ID">{{ request.postId }}</td>
                            <td data-label="Type">{{ formatPostType(request.postType) }}</td>
                            <td data-label="Reported By">{{ request.reportedByName || request.reportedBy }}</td>
                            <td data-label="Reported At">{{ request.reportedAt | prettyDateTime }}</td>
                            <td data-label="Status">
                                <span
                                    :class="{
                                        status: true,
                                        pending: !request.acknowledgedAt,
                                        acknowledged: request.acknowledgedAt,
                                    }"
                                >
                                    {{ request.acknowledgedAt ? "Acknowledged" : "Pending" }}
                                </span>
                            </td>
                            <td data-label="Acknowledged By">
                                {{ request.acknowledgedByName || "-" }}
                            </td>
                            <td data-label="Actions">
                                <button class="button review-btn" @click="reviewRequest(request)" :disabled="!!request.acknowledgedAt">
                                    {{ $t("admin.moderationList.review") }}
                                </button>
                            </td>
                        </tr>
                    </tbody>
                </table>
            </div>

            <div class="pagination-container" v-if="totalPages > 1">
                <PaginationControls :page="page" :totalPages="totalPages" @new-page="onNewPage" />
            </div>

            <ModerationReviewModal
                :show="selectedRequest !== null"
                :request="selectedRequest || {}"
                :content="requestContent"
                @close="closeReviewModal"
                @action-complete="onActionComplete"
            />
        </div>
    </StandardLayout>
</template>

<script lang="ts">
import Vue from "vue";
import StandardLayout from "../StandardLayout.vue";
import CommonComponents from "@/views/shared";
import PaginationControls from "@/views/shared/PaginationControls.vue";
import ModerationReviewModal from "./ModerationReviewModal.vue";
import { PostType, ModerationRequest } from "@/api/api";

export default Vue.extend({
    name: "AdminModeration",
    components: {
        StandardLayout,
        ...CommonComponents,
        PaginationControls,
        ModerationReviewModal,
    },
    data() {
        return {
            moderationRequests: [] as ModerationRequest[],
            totalPages: 0,
            busy: false,
            selectedRequest: null as ModerationRequest | null,
            requestContent: "",
            pageSize: 10,
        };
    },
    computed: {
        page(): number {
            const pageQuery = this.$route.query.page;
            return pageQuery ? parseInt(pageQuery as string, 10) : 0;
        },
    },
    methods: {
        formatPostType(type: PostType): string {
            switch (type) {
                case PostType.DISCUSSION_POST:
                    return this.$tc("admin.moderationList.postTypes.discussionPost");
                case PostType.DATA_EVENT:
                    return this.$tc("admin.moderationList.postTypes.dataEvent");
                default:
                    return type;
            }
        },
        async reviewRequest(request: ModerationRequest) {
            this.selectedRequest = request;
            try {
                const content = await this.$services.api.getModerationContent(request.postType, request.postId);
                this.requestContent = content;
            } catch (error) {
                this.requestContent = this.$tc("admin.moderationList.errorLoadingContent");
            }
        },
        closeReviewModal() {
            this.selectedRequest = null;
            this.requestContent = "";
        },
        async onActionComplete() {
            await this.loadModerationRequests();
            this.closeReviewModal();
        },
        onNewPage(page: number) {
            window.scrollTo(0, 0);

            this.$nextTick(() => {
                this.$router
                    .push({
                        path: this.$route.path,
                        query: { page: page.toString() },
                    })
                    .then(() => {
                        this.loadModerationRequests();
                    });
            });
        },
        async loadModerationRequests() {
            this.busy = true;
            try {
                const response = await this.$services.api.getModerationRequests(this.page, this.pageSize);
                this.moderationRequests = response.requests;
                this.totalPages = response.totalPages;
            } catch (error) {
                console.error("Error loading moderation requests:", error);
            } finally {
                this.busy = false;
            }
        },
    },
    mounted() {
        // add page param if not present
        if (this.$route.query.page === undefined) {
            this.$router
                .replace({
                    name: "adminModeration",
                    query: { page: "0" },
                })
                .catch((err) => {
                    if (err.name !== "NavigationDuplicated") {
                        throw err;
                    }
                });
            this.loadModerationRequests();
        } else {
            this.loadModerationRequests();
        }
    },
});
</script>

<style scoped lang="scss">
.admin-moderation {
    padding: 20px;
}

.loading-container,
.empty-state {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 200px;
}

.table-responsive {
    overflow-x: auto;
}

.moderation-table {
    width: 100%;
    border-collapse: collapse;

    th,
    td {
        padding: 12px 16px;
        text-align: left;
        border-bottom: 1px solid #eee;
    }

    th {
        background-color: #f8f9fa;
        font-weight: 600;
    }
}

.status {
    padding: 4px 8px;
    border-radius: 4px;
    font-size: 13px;

    &.pending {
        background-color: #fff3cd;
        color: #856404;
    }

    &.acknowledged {
        background-color: #d4edda;
        color: #155724;
    }
}

.review-btn {
    background-color: #007bff;
    color: white;
    border: none;
    border-radius: 4px;
    padding: 6px 12px;
    cursor: pointer;

    &:hover {
        background-color: #0069d9;
    }

    &:disabled {
        background-color: #6c757d;
        cursor: not-allowed;
    }
}

.pagination-container {
    margin-top: 20px;
    display: flex;
    justify-content: center;
}

@media (max-width: 768px) {
    .moderation-table {
        display: block;

        thead {
            display: none;
        }

        tbody,
        tr {
            display: block;
        }

        tr {
            margin-bottom: 16px;
            border: 1px solid #ddd;
            border-radius: 6px;
        }

        td {
            display: flex;
            justify-content: space-between;
            padding: 10px 16px;
            border-bottom: 1px solid #eee;

            &:before {
                content: attr(data-label);
                font-weight: 600;
                margin-right: 10px;
            }

            &:last-child {
                border-bottom: none;
                justify-content: flex-end;

                &:before {
                    content: "";
                }
            }
        }
    }
}
</style>
