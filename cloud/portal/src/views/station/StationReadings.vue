<template>
    <ul>
        <li v-for="module in station.modules" v-bind:key="module.id" class="reading-item">
            <header>{{ getModuleName(module) }}</header>
            <LatestStationReadings :id="station.id" :moduleKey="getModuleKey(module)" />
        </li>
    </ul>
</template>

<script lang="ts">
import Vue, { PropType } from "vue";
import { DisplayModule, DisplayStation } from "@/store";
import * as utils from "@/utilities";
import { BookmarkFactory, serializeBookmark } from "@/views/viz/viz";
import LatestStationReadings from "@/views/shared/LatestStationReadings.vue";

export default Vue.extend({
    name: "StationReadings",
    components: {
        LatestStationReadings,
    },
    props: {
        station: {
            type: Object as PropType<DisplayStation>,
            default: null,
        },
    },
    data() {
        return {};
    },
    methods: {
        getModuleImg(module: DisplayModule): string {
            return this.$loadAsset(utils.getModuleImg(module));
        },
        getModuleName(module: DisplayModule): string {
            return module.label || this.$tc(module.name.replace("modules.", "fk."));
        },
        getModuleKey(module: DisplayModule): string {
            return utils.getModuleKey(module);
        },
        onModuleClick(moduleId: number) {
            const tinyChartComp = this.$refs["tinyChart-" + moduleId];
            if (tinyChartComp && tinyChartComp[0]) {
                const vizData = tinyChartComp[0].vizData;
                if (vizData) {
                    const bm = BookmarkFactory.forSensor(this.station.id, vizData.vizSensor, vizData.timeRange);
                    const url = this.$router.resolve({
                        name: "exploreBookmark",
                        query: { bookmark: serializeBookmark(bm) },
                    }).href;
                    window.open(url, "_blank");
                }
            }
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/variables";
@use "src/scss/mixins";

::v-deep .no-readings-text {
    font-size: 14px;
}

.reading-item {
    margin-top: 25px;
    padding-top: 23px;
    border-top: solid 1px #d8dce0;

    header {
        font-size: 20px;
        margin-bottom: 15px;
    }
}
</style>
