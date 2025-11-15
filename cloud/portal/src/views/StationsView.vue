<template>
    <StandardLayout :viewingStations="true" :viewingStation="activeStation" @sidebar-toggle="onSidebarToggle">
        <template v-if="viewType === 'list'">
            <div class="stations-list" v-if="stations && stations.length > 0">
                <div v-for="station in stations" v-bind:key="station.id">
                    <StationHoverSummary
                        class="summary-container"
                        @close="closeSummary"
                        :station="station"
                        :sensorDataQuerier="sensorDataQuerier"
                        v-slot="{ sensorDataQuerier, station }"
                    >
                        <TinyChart :station-id="station.id" :station="station" :querier="sensorDataQuerier" />
                    </StationHoverSummary>
                </div>
            </div>
        </template>

        <template v-if="viewType === 'map'">
            <div class="container-map">
                <template v-if="!isCustomisationEnabled()">
                    <StationsMap
                        v-if="mapped"
                        :mapped="mapped"
                        :layoutChanges="layoutChanges"
                        :showStations="true"
                        :showSidebar="true"
                        :showHeader="true"
                        @show-summary="showSummary"
                    >
                        <StationsMapSummary
                            v-if="activeStation"
                            v-slot="{ sensorDataQuerier }"
                            :station="activeStation"
                            :sensorDataQuerier="sensorDataQuerier"
                            @close="closeSummary"
                        >
                            <TinyChart :station-id="activeStation.id" :station="activeStation" :querier="sensorDataQuerier" />
                        </StationsMapSummary>
                    </StationsMap>
                </template>

                <template v-else>
                    <StationsMap
                        v-if="mapped"
                        :mapped="mapped"
                        :layoutChanges="layoutChanges"
                        :showStations="true"
                        @show-summary="showSummary"
                    />
                    <StationHoverSummary
                        v-if="activeStation"
                        class="summary-container"
                        @close="closeSummary"
                        :station="activeStation"
                        :sensorDataQuerier="sensorDataQuerier"
                        :hasCupertinoPane="true"
                        v-slot="{ sensorDataQuerier }"
                    >
                        <TinyChart :station-id="activeStation.id" :station="activeStation" :querier="sensorDataQuerier" />
                    </StationHoverSummary>
                </template>
            </div>
        </template>
        <div class="no-stations" v-if="isAuthenticated && showNoStationsMessage && hasNoStations">
            <h1 class="heading">{{ $tc("stations.addNew") }}</h1>
            <p class="text">
                {{ $tc("stations.noStations") }}
            </p>
            <a href="https://apps.apple.com/us/app/fieldkit-org/id1463631293?ls=1" target="_blank">
                <img alt="App store" src="@/assets/appstore.svg" width="150" />
            </a>
            <a href="https://play.google.com/store/apps/details?id=com.fieldkit&hl=en_US" target="_blank">
                <img alt="Google Play" src="@/assets/googleplay.svg" width="147" />
            </a>
        </div>

        <MapViewTypeToggle
            :routes="[
                { name: 'mapAllStations', label: 'map.toggle.map', viewType: 'map' },
                { name: 'listAllStations', label: 'map.toggle.list', viewType: 'list' },
            ]"
        ></MapViewTypeToggle>
    </StandardLayout>
</template>

<script lang="ts">
import { mapGetters, mapState } from "vuex";
import * as ActionTypes from "@/store/actions";
import { GlobalState } from "@/store/modules/global";
import { DisplayStation, MappedStations } from "@/store";
import { SensorDataQuerier } from "./shared/sensor_data_querier";

import Vue, { PropType } from "vue";
import StandardLayout from "./StandardLayout.vue";
import StationHoverSummary from "./shared/StationHoverSummary.vue";
import StationsMap from "./shared/StationsMap.vue";
import TinyChart from "@/views/viz/TinyChart.vue";
import MapViewTypeToggle from "@/views/shared/MapViewTypeToggle.vue";
import { MapViewType } from "@/api/api";
import { isCustomisationEnabled } from "@/views/shared/partners";
import StationsMapSummary from "@/views/shared/StationsMapSummary.vue";

export default Vue.extend({
    name: "StationsView",
    components: {
        StandardLayout,
        StationsMap,
        StationHoverSummary,
        TinyChart,
        MapViewTypeToggle,
        StationsMapSummary,
    },
    props: {
        id: {
            type: Number,
            required: false,
        },
        bounds: {
            type: Array as unknown as PropType<[[number, number], [number, number]]>,
            required: false,
        },
    },
    data(): {
        showNoStationsMessage: boolean;
        layoutChanges: number;
        sensorDataQuerier: SensorDataQuerier;
    } {
        // console.log("stations-view:data", this.stations);
        return {
            showNoStationsMessage: true,
            layoutChanges: 0,
            sensorDataQuerier: new SensorDataQuerier(this.$services.api),
        };
    },
    computed: {
        ...mapGetters({ isAuthenticated: "isAuthenticated", isBusy: "isBusy" }),
        ...mapState({
            user: (s: GlobalState) => s.user.user,
            hasNoStations: (s: GlobalState) => s.stations.hasNoStations,
            stations: (s: GlobalState) => Object.values(s.stations.user.stations),
            userProjects: (s: GlobalState) => Object.values(s.stations.user.projects),
            anyStations: (s: GlobalState) => Object.values(s.stations.user.stations).length > 0,
        }),
        activeStation(): DisplayStation {
            return this.$state.stations.stations[this.id];
        },
        mapped(): MappedStations | null {
            if (!this.$getters.mapped) {
                return null;
            }
            if (this.bounds) {
                console.log(`focusing bounds: ${this.bounds}`);
                return this.$getters.mapped.overrideBounds(this.bounds);
            }
            if (this.id) {
                console.log(`focusing station: ${this.id}`);
                return this.$getters.mapped.focusOn(this.id);
            }
            return this.$getters.mapped;
        },
        viewType(): MapViewType {
            if (this.$route.meta?.viewType) {
                return this.$route.meta.viewType;
            }
            return MapViewType.map;
        },
    },
    beforeMount(): Promise<any> {
        if (this.id) {
            return this.$store.dispatch(ActionTypes.NEED_STATION, { id: this.id });
        }
        return Promise.resolve();
    },
    watch: {
        stations() {
            // console.log("stations-view:stations", this.stations);
            this.sensorDataQuerier = new SensorDataQuerier(this.$services.api);
        },
        id(): Promise<any> {
            if (this.id) {
                return this.$store.dispatch(ActionTypes.NEED_STATION, { id: this.id });
            }
            return Promise.resolve();
        },
    },
    methods: {
        isCustomisationEnabled,
        goBack(): void {
            if (window.history.length) {
                this.$router.go(-1);
            } else {
                this.$router.push("/");
            }
        },
        boundsParam(): string | null {
            const mapped = this.mapped;
            if (!mapped || !mapped.bounds) return null;
            return JSON.stringify([mapped.bounds.min, mapped.bounds.max]);
        },
        async showSummary(params: { id: number }): Promise<void> {
            if (this.id != params.id) {
                const bounds = this.boundsParam();
                if (bounds) {
                    console.log(`clicked station, showing: ${params.id}`);
                    await this.$router.push({
                        name: "mapStationBounds",
                        params: {
                            id: String(params.id),
                            bounds: bounds,
                        },
                    });
                }
            }
        },
        async closeSummary(): Promise<void> {
            const bounds = this.boundsParam();
            if (bounds) {
                await this.$router.push({
                    name: "mapAllStationsBounds",
                    params: {
                        bounds: bounds,
                    },
                });
            }
            this.layoutChange();
        },
        layoutChange() {
            this.$nextTick(() => {
                this.layoutChanges++;
            });
        },
        onSidebarToggle() {
            this.layoutChange();
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/mixins.scss";
@use "src/scss/variables";

.container-map {
    width: 100%;
    height: calc(100% - 66px);
    margin-top: 0;
    @include mixins.position(absolute, 66px null null 0);

    ::v-deep .station-hover-summary {
        left: 50%;
        top: 50%;
        transform: translate(-50%, -50%);
    }

    @include mixins.bp-down(variables.$sm) {
        top: 54px;
        height: calc(100% - 54px);
    }
}

body:not(.floodnet) .container-map {
    box-shadow: 0 1px 4px 0 rgba(0, 0, 0, 0.12);
    max-height: calc(100vh - 66px);
    overflow: hidden;

    @include mixins.bp-down(variables.$xs) {
        max-height: calc(100vh - 54px);
    }
}

.no-stations {
    background-color: #ffffff;
    width: 486px;
    padding: 95px 80px 95px 80px;
    margin: 129px auto 60px auto;
    text-align: center;
    border: 1px solid rgb(215, 220, 225);
    z-index: 2;
    box-sizing: border-box;

    @include mixins.bp-down(variables.$xs) {
        width: calc(100% - 20px);
        padding: 31px 13px;
    }

    a {
        @include mixins.bp-down(variables.$xs) {
            display: block;
        }

        &:nth-of-type(1) {
            margin-right: 27px;

            @include mixins.bp-down(variables.$xs) {
                margin-right: 0;
                margin-bottom: 14px;
            }
        }
    }

    .heading {
        font-size: 18px;
        font-family: var(--font-family-bold);
        margin-bottom: 2px;
        margin-top: 0;
    }

    .text {
        font-size: 14px;
        max-width: 320px;
        margin: 0 auto 35px;
    }
}

::v-deep .stations-list {
    @include mixins.flex();
    flex-wrap: wrap;
    padding: 100px 40px;
    width: 100%;
    box-sizing: border-box;

    @include mixins.bp-down(variables.$md) {
        padding: 100px 20px;
        margin: 30px -20px -20px;
    }

    @include mixins.bp-down(variables.$sm) {
        justify-content: center;
    }

    @include mixins.bp-down(variables.$xs) {
        padding: 80px 0px;
        margin: 55px 0 -5px 0;
        transform: translateX(10px);
        width: calc(100% - 20px);
    }

    .station-hover-summary {
        z-index: 0;
        position: unset;
        margin: 20px;
        flex-basis: 389px;
        box-sizing: border-box;
        box-shadow: 0 2px 4px 0 rgba(0, 0, 0, 0.07);

        @include mixins.bp-down(variables.$md) {
            padding: 19px 11px;
            flex-basis: calc(50% - 40px);
        }

        @include mixins.bp-down(variables.$sm) {
            justify-self: center;
            flex: 1 1 389px;
            max-width: 389px;
            margin: 10px 0;
        }

        @include mixins.bp-down(variables.$xs) {
            margin: 5px 0;
            width: auto;
        }

        .close-button {
            display: none;
        }

        .navigate-button {
            right: -3px;
            top: -10px;
        }
    }
}

::v-deep .mapboxgl-ctrl-geocoder {
    margin: 24px 0 0 25px;

    @include mixins.bp-down(variables.$sm) {
        margin: 13px 0 0 10px;
    }
}

::v-deep .mapboxgl-ctrl-bottom-left {
    margin-left: 20px;
}

::v-deep .view-type-container {
    @include mixins.bp-down(variables.$sm) {
        top: 68px;
    }
}

body:not(.floodnet) .stations-map {
    height: calc(100% - 88px) !important;
}
</style>
