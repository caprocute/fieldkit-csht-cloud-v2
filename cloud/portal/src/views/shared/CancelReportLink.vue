<template>
    <button v-if="canCancel" @click="cancelReport" :disabled="isLoading">
        <i class="icon icon-close"></i>
        {{ isLoading ? $tc("cancelReport.canceling") : $tc("cancelReport.label") }}
    </button>
</template>

<script lang="ts">
import Vue from "vue";
import { PostType } from "@/api/api";
import { SnackbarStyle } from "@/store/modules/snackbar";
import { ActionTypes } from "@/store";

export default Vue.extend({
    name: "CancelReportLink",
    props: {
        postId: {
            type: Number,
            required: true,
        },
        postType: {
            type: String as () => PostType,
            required: true,
        },
        userHasReported: {
            type: Boolean,
            default: false,
        },
    },
    data() {
        return {
            isLoading: false,
        };
    },
    computed: {
        canCancel(): boolean {
            return this.userHasReported;
        },
    },
    methods: {
        async cancelReport() {
            this.isLoading = true;
            try {
                await this.$services.api.cancelModerationRequest(this.postId, this.postType);
                this.$emit("report-canceled");
                this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                    message: this.$tc("cancelReport.success"),
                    type: SnackbarStyle.success,
                });
            } catch (error) {
                console.error("Error canceling report:", error);
                this.$store.dispatch(ActionTypes.SHOW_SNACKBAR, {
                    message: this.$tc("cancelReport.error"),
                    type: SnackbarStyle.fail,
                });
            } finally {
                this.isLoading = false;
            }
        },
    },
});
</script>

<style scoped>
button {
    background: none;
    border: none;
    cursor: pointer;
    font-size: 12px;
    padding: 0;
    margin-left: 8px;
    display: inline-flex;
    align-items: center;
    gap: 3px;
    font-weight: bold;
}

button:hover {
    color: #333;
}

button:disabled {
    opacity: 0.6;
    cursor: not-allowed;
}

.icon {
    font-size: 10px;
}
</style>
