<template>
    <div class="modal-overlay" v-if="show" @click.self="close">
        <div class="modal-content">
            <h3>{{ $t("admin.moderationReview.title") }}</h3>
            <div class="content-details">
                <p>
                    <strong>{{ $t("admin.moderationReview.postType") }}:</strong>
                    {{ getPostTypeLabel(request.postType) }}
                </p>
                <p>
                    <strong>{{ $t("admin.moderationReview.reportedBy") }}:</strong>
                    {{ request.reportedByName || request.reportedBy }}
                </p>
                <p>
                    <strong>{{ $t("admin.moderationReview.content") }}:</strong>
                </p>
                <div class="content-box">
                    <TipTap :value="processedContent" :readonly="true" :showSaveButton="false" />
                </div>
            </div>
            <div class="actions">
                <button class="button delete-btn" @click="handleAction('delete')">
                    {{ $t("admin.moderationReview.actions.delete") }}
                </button>
                <button class="button keep-btn" @click="handleAction('keep')">
                    {{ $t("admin.moderationReview.actions.keep") }}
                </button>
                <button class="button cancel-btn" @click="close">
                    {{ $t("admin.moderationReview.actions.cancel") }}
                </button>
            </div>
        </div>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import TipTap from "@/views/shared/Tiptap.vue";
import { PostType } from "@/api/api";

interface ModerationRequest {
    id: number;
    postType: PostType;
    reportedBy: string;
    reportedByName?: string;
}

export default Vue.extend({
    name: "ModerationReviewModal",
    components: {
        TipTap,
    },
    props: {
        show: {
            type: Boolean,
            required: true,
        },
        request: {
            type: Object as () => ModerationRequest,
            required: true,
        },
        content: {
            type: String,
            required: true,
        },
    },
    computed: {
        processedContent(): any {
            if (!this.content) {
                return null;
            }
            try {
                return JSON.parse(this.content);
            } catch (error) {
                return {
                    type: "doc",
                    content: [
                        {
                            type: "paragraph",
                            content: [
                                {
                                    type: "text",
                                    text: this.content,
                                },
                            ],
                        },
                    ],
                };
            }
        },
    },
    methods: {
        close(): void {
            this.$emit("close");
        },
        async handleAction(action: "delete" | "keep"): Promise<void> {
            try {
                await this.$services.api.acknowledgeModerationRequest(this.request.id, action);
                this.$emit("action-complete");
                this.close();
            } catch (error) {
                console.error("Error handling moderation action:", error);
            }
        },
        getPostTypeLabel(postType: PostType): string {
            switch (postType) {
                case PostType.DISCUSSION_POST:
                    return this.$tc("admin.moderationReview.postTypes.discussionPost");
                case PostType.DATA_EVENT:
                    return this.$tc("admin.moderationReview.postTypes.dataEvent");
                default:
                    return postType;
            }
        },
    },
});
</script>

<style scoped>
.modal-overlay {
    position: fixed;
    top: 0;
    left: 0;
    right: 0;
    bottom: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    justify-content: center;
    align-items: center;
    z-index: 1000;
}

.modal-content {
    background: white;
    padding: 2rem;
    border-radius: 4px;
    max-width: 600px;
    width: 90%;
}

.content-box {
    background: #f5f5f5;
    padding: 1rem;
    margin: 1rem 0;
    border-radius: 4px;
    max-height: 300px;
    overflow-y: auto;
    white-space: pre-wrap;
}

.actions {
    display: flex;
    gap: 1rem;
    justify-content: flex-end;
    margin-top: 1rem;
}

.delete-btn {
    background: #dc3545;
    color: white;
}

.keep-btn {
    background: #28a745;
    color: white;
}

.cancel-btn {
    background: #6c757d;
    color: white;
}
</style>
