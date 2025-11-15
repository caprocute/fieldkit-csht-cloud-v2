<template class="wrap">
    <img v-if="photo && !processing" :src="photo" class="authenticated-photo photo" :class="{ processing: processing }" alt="Image" />
    <div v-else-if="notFound" class="not-found">
        <i class="fas fa-image"></i>
    </div>
    <Spinner v-else class="spinner" />
</template>

<script lang="ts">
import Vue from "vue";
import Spinner from "@/views/shared/Spinner.vue";

export default Vue.extend({
    name: "AuthenticatedPhoto",
    components: {
        Spinner,
    },
    props: {
        url: {
            type: String,
            required: true,
        },
        processing: {
            type: Boolean,
            default: false,
        },
    },
    data() {
        return {
            photo: null,
            notFound: false,
        };
    },
    watch: {
        url(this: any) {
            return this.refresh();
        },
        processing(newVal) {
            this.$emit("loading-change", newVal);
        },
    },
    created(this: any) {
        return this.refresh();
    },
    methods: {
        refresh(this: any) {
            return this.$services.api.loadMedia(this.url).then((photo) => {
                this.photo = photo;
            }).catch((error) => {
                if (error.status === 404) {
                    // Silently handle 404, let parent component handle visualization
                    return;
                }
                // Let other errors propagate
                throw error;
            });
        },
    },
});
</script>

<style scoped lang="scss">
.photo {
    transition: all 0.25s;
}

.photo.processing {
    opacity: 0.5;
    filter: blur(3px);
}

.spinner {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
}

.not-found {
    display: flex;
    align-items: center;
    justify-content: center;
    width: 100%;
    height: 100%;
    background-color: #f5f5f5;
    color: #999;
    font-size: 2em;
}
</style>
