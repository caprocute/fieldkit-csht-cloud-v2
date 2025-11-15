<template>
    <div :class="['sidebar', { open: isOpen }]" @click.stop class="js-cupertinoPane" ref="paneContent">
        <button class="sidebar-toggle" @click="toggleSidebar"><i class="icon icon-filter"></i></button>
        <div class="sidebar-content" ref="summaryContent" @click="$event.stopPropagation()">
            <div class="heading">{{ $t("map.sidebar.viewing.heading", { stationsLength: stations.length }) }}</div>
            <label class="update-map-results-checkbox checkbox">
                <input id="updateResultsBasedOnMap" type="checkbox" @change="onUpdateResultsBasedOnMap" />
                <span class="checkbox-btn"></span>
                {{ $t("map.sidebar.viewing.updateMapCheckbox") }}
            </label>
            <!--
                <button class="button">{{ $t("map.sidebar.viewing.exploreBtn") }}</button>
            -->
            <div class="station-list">
                <div v-if="stations.length == 0">{{ $t("map.sidebar.viewing.noStationsOnMap") }}</div>
                <div
                    class="station-list-item"
                    v-for="station in stations"
                    v-bind:key="station.id"
                    @click="selectStation(station.id)"
                    :class="{ selected: $route.params.id == station.id }"
                >
                    <StationSummaryContent ref="summaryContent" :station="station">
                        <template #top-right-actions>
                            <img
                                :alt="$tc('station.navigateToStation')"
                                class="navigate-button"
                                src="@/assets/tooltip-fieldkit.svg"
                                @click="openStationPageTab(station.id)"
                            />
                        </template>
                    </StationSummaryContent>
                </div>
            </div>
        </div>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import StationSummaryContent from "@/views/shared/StationSummaryContent.vue";
import { CupertinoPane } from "cupertino-pane";
import debounce from "lodash/debounce";

export default Vue.extend({
    name: "StationsMapSidebar",
    components: { StationSummaryContent },
    props: {
        stations: {
            required: true,
        },
    },
    data(): {
        isOpen: boolean;
        cupertinoPane: CupertinoPane | null;
        onResize: any;
    } {
        return {
            isOpen: true,
            cupertinoPane: null,
            onResize: null,
        };
    },
    mounted() {
        this.initCupertinoPane();
        this.onResize = debounce(() => {
            this.destroyCupertinoPane();
            this.initCupertinoPane();
        }, 300);
        window.addEventListener("resize", this.onResize);
    },
    destroyed() {
        this.destroyCupertinoPane();
        window.removeEventListener("resize", this.onResize);
    },
    methods: {
        toggleSidebar() {
            this.isOpen = !this.isOpen;
            this.$emit("toggle");
        },
        openStationPageTab(stationId: number) {
            const routeData = this.$router.resolve({ name: "viewStationFromMap", params: { stationId: stationId.toString() } });
            window.open(routeData.href, "_blank");
        },
        onUpdateResultsBasedOnMap(event) {
            this.$emit("update-results-based-on-map", event.target.checked);
        },
        async initCupertinoPane(): Promise<void> {
            if (window.screen.availWidth > 1040) {
                return;
            }
            this.cupertinoPane = new CupertinoPane(".js-cupertinoPane", {
                parentElement: "body",
                breaks: {
                    top: { enabled: true, height: window.screen.availHeight / 1.3, bounce: true },
                    middle: { enabled: true, height: window.screen.availHeight / 2, bounce: true },
                    bottom: { enabled: true, height: 60 },
                },
                bottomClose: false,
                buttonDestroy: false,
            });
            this.cupertinoPane.present({ animate: true });
        },
        destroyCupertinoPane(): void {
            if (this.cupertinoPane && window.screen.availWidth > 1040) {
                this.cupertinoPane.destroy();
                this.cupertinoPane = null;
            }
        },
        selectStation(id: number) {
            this.$emit("select-station", id);
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/variables";
@use "src/scss/mixins";

.sidebar {
    height: calc(100% - 88px);
    width: 0;
    transform: translateX(-100%);
    border: solid 1px #f4f5f7;
    background-color: #fff;
    z-index: variables.$z-index-top;
    text-align: left;
    display: flex;
    flex-direction: column;
    box-sizing: border-box;
    margin-top: 1px;
    margin-left: 1px;

    @include mixins.bp-down(variables.$lg) {
        border: 0;
    }
}

.sidebar-toggle {
    position: absolute;
    left: 0;
    top: 140px;
    z-index: variables.$z-index-top;
    padding: 9px 8px;
    box-shadow: 0 2px 4px 0 rgba(0, 0, 0, 0.13);
    border: solid 1px #f4f5f7;
    background-color: #fff;

    .icon {
        font-size: 20px;
    }
}

.heading {
    font-size: 25px;
    font-weight: 900;
    margin-bottom: 7px;
    color: var(--color-dark);

    @include mixins.bp-down(variables.$xs) {
        font-size: 16px;
        text-align: center;
    }
}

.sidebar.open {
    transform: translateX(0);
    width: 480px;
    max-width: 100%;
    padding: 20px 10px 20px 20px;

    @include mixins.bp-down(variables.$xs) {
        padding-top: 10px;
    }

    .sidebar-toggle {
        left: 480px;
    }
}

.sidebar-content {
    height: 100%;
    box-sizing: border-box;
    display: flex;
    flex-direction: column;
    overflow: hidden;
}

.button {
    font-weight: 900;
    font-size: 14px;
    font-family: variables.$font-family-fieldkit-medium;
}

.station-list-item {
    padding: 27px 18px 25px 25px;
    border-radius: 3px;
    box-shadow: 0 2px 4px 0 rgba(0, 0, 0, 0.07);
    border: solid 1px #d8dce0;
    background-color: #fff;
    margin-bottom: 16px;

    @include mixins.bp-down(variables.$xs) {
        padding: 17px 15px 10px 15px;
    }

    ::v-deep {
        .station-name {
            font-size: 16px;
        }

        .image-container {
            flex: 0 0 93px;
            height: 93px;
        }

        .navigate-button {
            position: absolute;
            right: 0;
            top: 0;
            cursor: pointer;
        }

        .image-container img {
            border-radius: 5px;
        }
    }
}

.station-list-item.selected {
    background-color: #f4f5f7;
}

.update-map-results-checkbox {
    font-size: 14px;
    color: #000;
    display: flex;
    align-items: flex-end;
    margin-bottom: 23px;
    user-select: none;

    input {
        margin-right: 8px;
        margin-left: 0;
    }
}

.station-list {
    flex-grow: 1;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    padding-right: 16px;
}
</style>
