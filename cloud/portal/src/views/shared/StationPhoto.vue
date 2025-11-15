<template>
    <div v-if="loading" class="station-photo loading-container">
        <Spinner class="spinner" />
    </div>
    <img v-else-if="station.photos && photo" :src="photo" class="station-photo photo" :alt="$t('station.photo.alt')" />
    <img
        v-else
        :src="$loadAsset(interpolatePartner('station-image-placeholder-') + '.png')"
        class="station-photo photo"
        :alt="$t('station.photo.default.alt')"
    />
</template>

<script lang="ts">
import Vue, { PropType } from "vue";
import { DisplayStation } from "@/store";
import Spinner from "./Spinner.vue";
import { interpolatePartner } from "@/views/shared/partners";

export default Vue.extend({
    name: "StationPhoto",
    components: {
        Spinner,
    },
    props: {
        station: {
            type: Object as PropType<DisplayStation>,
            required: true,
        },
        size: {
            type: Number,
            default: 125,
        },
    },
    data(): {
        photo: unknown | null;
        loading: boolean;
    } {
        return {
            photo: null,
            loading: false,
        };
    },
    watch: {
        async station(): Promise<void> {
            await this.refresh();
        },
    },
    async mounted(): Promise<void> {
        await this.refresh();
    },
    methods: {
        async refresh(): Promise<void> {
            // console.log(`loading-photo:`, this.station);
            if (this.station.photos) {
                const isRetinaDisplay = window.devicePixelRatio > 1;
                const photoSize = isRetinaDisplay ? this.size * 2 : this.size;
                this.loading = true;
                try {
                    const photo = await this.$services.api.loadMedia(this.station.photos.small, { size: photoSize });
                    this.photo = photo;
                } finally {
                    this.loading = false;
                }
            }
        },
        interpolatePartner(baseString: string): string {
            return interpolatePartner(baseString);
        },
    },
});
</script>

<style scoped lang="scss"></style>
