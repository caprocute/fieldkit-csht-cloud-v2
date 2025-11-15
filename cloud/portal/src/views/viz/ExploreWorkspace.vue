<template>
    <StandardLayout @show-station="showStation" :defaultShowStation="false" :disableScrolling="exportsVisible || shareVisible">
        <ExportPanel v-if="exportsVisible" containerClass="exports-floating" :bookmark="bookmark" @close="closePanel" />

        <SharePanel v-if="shareVisible" containerClass="share-floating" :token="token" :bookmark="bookmark" @close="closePanel" />

        <ExportChartContent></ExportChartContent>

        <div class="explore-view">
            <div class="explore-header">
                <div class="explore-links">
                    <a v-for="link in partnerCustomization().links" v-bind:key="link.url" :href="link.url" target="_blank" class="link">
                        {{ $t(link.text) }} >
                    </a>
                </div>
                <DoubleHeader :backTitle="backTitle" @back="onBack">
                    <template v-slot:title>
                        <div class="one">
                            {{ $tc("dataView.title") }}

                            <InfoTooltip :message="$tc('dataView.computerTip')"></InfoTooltip>

                            <div
                                class="button compare"
                                :class="{ disabled: addChartDisabled }"
                                :alt="$tc('dataView.buttons.addChart')"
                                @click="addChart"
                            >
                                <img :src="addIcon" />
                                <div>{{ $tc("dataView.buttons.addChart") }}</div>
                            </div>
                        </div>
                    </template>
                    <template v-slot:default>
                        <div class="button-submit" @click="openShare">
                            <i class="icon icon-share"></i>
                            <span class="button-submit-text">{{ $tc("dataView.buttons.share") }}</span>
                        </div>
                        <div class="button-submit" @click="openExports" v-if="exportSupported()">
                            <i class="icon icon-export"></i>
                            <span class="button-submit-text">{{ $tc("dataView.buttons.export") }}</span>
                        </div>
                    </template>
                </DoubleHeader>
            </div>

            <div v-if="showNoSensors" class="notification">{{ $tc("dataView.noSensors") }}</div>

            <div v-if="!workspace && !bookmark">{{ $tc("dataView.nothingSelected") }}</div>

            <div class="workspace-container" v-if="!workspace && currentStation">
                <div class="station-summary">
                    <StationSummaryContent :station="currentStation" class="summary-content">
                        <template #top-right-actions>
                            <img
                                :alt="$tc('station.navigateToStation')"
                                class="navigate-button"
                                :src="$loadAsset(interpolatePartner('tooltip-') + '.svg')"
                                @click="openStationPageTab"
                            />
                        </template>
                    </StationSummaryContent>
                </div>
            </div>

            <div v-bind:class="{ 'workspace-container': true, busy: busy }">
                <div class="busy-panel" v-if="busy">
                    <Spinner></Spinner>
                </div>

                <div class="station-summary" v-if="selectedStation">
                    <StationSummaryContent :station="selectedStation" v-if="workspace && !workspace.empty" class="summary-content">
                        <template #extra-detail>
                            <StationBattery :station="selectedStation" />
                        </template>
                        <template #top-right-actions>
                            <img
                                :alt="$tc('station.navigateToStation')"
                                class="navigate-button"
                                :src="$loadAsset(interpolatePartner('tooltip-') + '.svg')"
                                @click="openStationPageTab"
                            />
                        </template>
                    </StationSummaryContent>

                    <div class="pagination" v-if="workspace && !workspace.empty">
                        <PaginationControls
                            :page="selectedIndex"
                            :totalPages="getValidStations().length"
                            @new-page="onNewSummaryStation"
                            textual
                            wrap
                        />
                    </div>
                </div>

                <VizWorkspace
                    v-if="workspace && !workspace.empty"
                    :workspace="workspace"
                    @change="onChange"
                    @event-clicked="eventClicked"
                />

                <Comments
                    :parentData="bookmark"
                    :workspace="workspace"
                    :user="user"
                    @viewDataClicked="onChange"
                    v-if="bookmark && !busy"
                ></Comments>
            </div>
        </div>
    </StandardLayout>
</template>

<script lang="ts">
import Promise from "bluebird";

import _ from "lodash";
import Vue from "vue";
import CommonComponents from "@/views/shared";
import StandardLayout from "../StandardLayout.vue";
import ExportPanel from "./ExportPanel.vue";
import SharePanel from "./SharePanel.vue";
import StationSummaryContent from "../shared/StationSummaryContent.vue";
import PaginationControls from "@/views/shared/PaginationControls.vue";
import {
    getPartnerCustomization,
    getPartnerCustomizationWithDefault,
    interpolatePartner,
    isCustomisationEnabled,
    PartnerCustomization,
} from "../shared/partners";
import { mapGetters, mapState } from "vuex";
import { ActionTypes, DisplayStation } from "@/store";
import { GlobalState } from "@/store/modules/global";
import { SensorsResponse } from "./api";
import { Bookmark, ChartType, FastTime, Graph, Time, VizSensor, VizSettings, Workspace } from "./viz";
import { VizWorkspace } from "./VizWorkspace";
import { getBatteryIcon, isMobile } from "@/utilities";
import Comments from "../comments/Comments.vue";
import StationBattery from "@/views/station/StationBattery.vue";
import InfoTooltip from "@/views/shared/InfoTooltip.vue";
import Spinner from "@/views/shared/Spinner.vue";
import { confirmLeaveWithDirtyCheck } from "@/store/modules/dirty";
import ExportChartContent from "@/views/viz/vega/ExportChartContent.vue";
import project from "vega-lite/build/src/compile/selection/project";

export default Vue.extend({
    name: "ExploreWorkspace",
    components: {
        ExportChartContent,
        ...CommonComponents,
        StandardLayout,
        VizWorkspace,
        SharePanel,
        ExportPanel,
        Comments,
        StationSummaryContent,
        PaginationControls,
        StationBattery,
        InfoTooltip,
        Spinner,
    },
    props: {
        token: {
            type: String,
            required: false,
        },
        bookmark: {
            type: Bookmark,
            required: true,
        },
        exportsVisible: {
            type: Boolean,
            default: false,
        },
        shareVisible: {
            type: Boolean,
            default: false,
        },
    },
    data(): {
        workspace: Workspace | null;
        showNoSensors: boolean;
        selectedIndex: number;
        validStations: number[];
    } {
        return {
            workspace: null,
            showNoSensors: false,
            selectedIndex: 0,
            validStations: [],
        };
    },
    computed: {
        project() {
            return project;
        },
        ...mapGetters({ isAuthenticated: "isAuthenticated" }),
        ...mapState({
            user: (s: GlobalState) => s.user.user,
            stations: (s: GlobalState) => s.stations.user.stations,
            userProjects: (s: GlobalState) => s.stations.user.projects,
        }),
        addIcon(): unknown {
            return this.$loadAsset("icon-compare.svg");
        },
        busy(): boolean {
            if (isMobile()) {
                return !this.workspace;
            }
            return !this.workspace || this.workspace.busy;
        },
        backTitle(): string | null {
            const hasProjectContext = this.bookmark && this.bookmark.c;
            if (!hasProjectContext && !this.isAuthenticated) {
                return null;
            }

            const partnerCustomization = getPartnerCustomization();
            if (this.bookmark && this.bookmark.c) {
                if (!this.bookmark.c.map) {
                    return this.$tc("layout.backProjectDashboard");
                }
            }
            if (partnerCustomization) {
                return this.$tc(partnerCustomization.nav.viz.back.map.label);
            }
            return this.$tc("layout.backToStations");
        },
        selectedId(): number {
            return Number(_.flattenDeep(this.bookmark.g)[0]);
        },
        selectedStation(): DisplayStation | null {
            if (this.workspace) {
                return this.workspace.getStation(this.workspace.selectedStationId);
            }
            return null;
        },
        currentStation(): DisplayStation | null {
            return this.bookmark.s.length > 0 ? this.$getters.stationsById[this.bookmark.s[0]] : null;
        },
        // Disabled button when there's only 1 viz and it has no data
        addChartDisabled(): boolean {
            if (!this.workspace) return false;

            const allVizes = this.workspace.groups.flatMap((group) => group.vizes);
            if (allVizes.length !== 1) return false;

            const viz = allVizes[0];
            return viz instanceof Graph && viz.isDataSetEmpty();
        },
    },
    watch: {
        async bookmark(newValue: Bookmark, _oldValue: Bookmark): Promise<void> {
            console.log(`viz: bookmark-route(ew):`, newValue);
            if (this.workspace) {
                await this.workspace.updateFromBookmark(newValue);
            } else {
                await this.createWorkspaceIfNecessary();
            }
        },
        async selectedId(newValue: number, _oldValue: number): Promise<void> {
            console.log("viz: selected-changed-associated", newValue);
        },
    },
    async beforeMount(): Promise<void> {
        if (this.bookmark) {
            await this.$services.api
                .getAllSensorsMemoized()() // TODO No need to make this call.
                .then(async () => {
                    // Check for a bookmark that is just to a station with no groups.
                    if (this.bookmark.s.length > 0 && this.bookmark.g.length == 0) {
                        console.log("viz: before-show-station", this.bookmark);
                        return this.showStation(this.bookmark.s[0]);
                    }

                    console.log("viz: before-create-workspace", this.bookmark);
                    await this.createWorkspaceIfNecessary();
                })
                .catch(async (e) => {
                    if (e.name === "ForbiddenError") {
                        await this.$router.push({ name: "login", params: { errorMessage: String(this.$t("login.privateStation")) } });
                    }
                });
        }
        await this.$store.dispatch(ActionTypes.SET_REFRESH_WORKSPACE_FN, this.refreshWorkspace);
    },
    methods: {
        isCustomisationEnabled,
        refreshWorkspace() {
            this.workspace = null;
            this.createWorkspaceIfNecessary();
        },
        async onBack() {
            if (this.bookmark.c) {
                if (this.bookmark.c.map) {
                    await this.$router.push({ name: "viewProjectBigMap", params: { id: String(this.bookmark.c.project) } });
                } else {
                    await this.$router.push({ name: "viewProject", params: { id: String(this.bookmark.c.project) } });
                }
            } else {
                await this.$router.push({ name: "mapAllStations" });
            }
        },
        async addChart() {
            console.log("viz: add");
            if (this.addChartDisabled) {
                throw new Error("viz-add: no workspace");
            }
            return this.workspace!.addChart().query();
        },
        async onChange(bookmark: Bookmark): Promise<void> {
            if (Bookmark.sameAs(this.bookmark, bookmark)) {
                // console.log("viz: bookmark-no-change", bookmark);
                return Promise.resolve(this.workspace);
            }
            console.log("viz: bookmark-change", bookmark);
            await this.openBookmark(bookmark);
        },
        async openBookmark(bookmark: Bookmark): Promise<void> {
            this.$emit("open-bookmark", bookmark);
        },
        async openExports(): Promise<void> {
            this.$emit("export");
        },
        async openShare(): Promise<void> {
            this.$emit("share");
        },
        async closePanel(): Promise<void> {
            return await this.openBookmark(this.bookmark);
        },
        async createWorkspaceIfNecessary(): Promise<Workspace> {
            if (this.workspace) {
                return this.workspace;
            }

            console.log("viz: workspace-creating");

            const settings = new VizSettings(isMobile());
            const allSensors: SensorsResponse = await this.$services.api.getAllSensorsMemoized()();
            const ws = this.bookmark ? Workspace.fromBookmark(allSensors, this.bookmark, settings) : new Workspace(allSensors, settings);

            this.workspace = await ws.initialize();

            console.log(`viz: workspace-created`);

            return ws;
        },
        async showStation(stationId: number): Promise<void> {
            console.log("viz: show-station", stationId);

            return confirmLeaveWithDirtyCheck(async () => {
                return await this.$services.api
                    .getQuickSensors([stationId])
                    .then(async (quickSensors) => {
                        console.log("viz: quick-sensors", quickSensors);
                        if (quickSensors.stations[stationId].filter((r) => r.moduleId != null).length == 0) {
                            console.log("viz: no sensors TODO: FIX");
                            this.showNoSensors = true;
                            return Promise.delay(5000).then(() => {
                                this.showNoSensors = false;
                            });
                        }

                        const sensorModuleId = quickSensors.stations[stationId][0].moduleId;
                        const sensorId = quickSensors.stations[stationId][0].sensorId;
                        const vizSensor: VizSensor = [stationId, [sensorModuleId, sensorId]];

                        const associated = await this.$services.api.getAssociatedStations(stationId);
                        // First station ID should be the station we're opening.
                        const stationIds = _.sortBy(
                            associated.stations.map((associatedStation) => associatedStation.station.id),
                            (id) => {
                                if (id == stationId) {
                                    return 0;
                                }
                                return id;
                            }
                        );
                        console.log(`viz: show-station-associated`, { associated, stationIds });

                        const getInitialBookmark = () => {
                            const quickSensor = quickSensors.stations[stationId].filter((qs) => qs.sensorId == sensorId);
                            if (quickSensor.length == 1) {
                                const end = new Date(quickSensor[0].sensorReadAt);
                                const start = new Date(end);

                                if (isMobile()) {
                                    start.setDate(end.getDate() - 1); // TODO Use getFastTime
                                } else {
                                    start.setDate(end.getDate() - 14); // TODO Use getFastTime
                                }

                                return new Bookmark(
                                    this.bookmark.v,
                                    [[[[[vizSensor], [start.getTime(), end.getTime()], [], ChartType.TimeSeries, FastTime.TwoWeeks]]]],
                                    stationIds,
                                    this.bookmark.p,
                                    this.bookmark.c
                                );
                            }

                            console.log("viz: ERROR missing expected quick row, default to FastTime.All");

                            return new Bookmark(
                                this.bookmark.v,
                                [[[[[vizSensor], [Time.Min, Time.Max], [], ChartType.TimeSeries, FastTime.All]]]],
                                stationIds,
                                this.bookmark.p,
                                this.bookmark.c
                            );
                        };

                        this.$emit("open-bookmark", getInitialBookmark());
                    })
                    .catch(async (e) => {
                        if (e.name === "ForbiddenError") {
                            await this.$router.push({ name: "login", params: { errorMessage: String(this.$t("login.privateStation")) } });
                        }
                    });
            }, this);
        },
        getValidStations(): number[] {
            if (this.workspace == null) {
                return [];
            }

            const validStations = this.workspace.stationsMetas
                .filter((station) => !station.hidden && station.sensors.length > 0)
                .map((d) => d.id);

            this.selectedIndex = validStations.indexOf(this.selectedId);

            return validStations;
        },
        onNewSummaryStation(evt) {
            const stations = this.getValidStations();
            this.showStation(stations[evt]);
            this.selectedIndex = evt;
        },
        openStationPageTab() {
            const station = this.selectedStation ? this.selectedStation : this.currentStation;
            if (station) {
                const routeData = this.$router.resolve({
                    name: "viewStationFromMap",
                    params: { stationId: String(station.id) },
                });
                window.open(routeData.href, "_blank");
            }
        },
        getBatteryIcon() {
            if (this.selectedStation == null) {
                return null;
            }
            return this.$loadAsset(getBatteryIcon(this.selectedStation.battery));
        },
        interpolatePartner(baseString) {
            return interpolatePartner(baseString);
        },
        partnerCustomization(): PartnerCustomization {
            return getPartnerCustomizationWithDefault();
        },
        eventClicked(id: number): void {
            this.$emit("event-clicked", id);
        },
        exportSupported(): boolean {
            if (this.workspace == null) {
                return false;
            }

            if (!this.partnerCustomization().exportSupported) {
                return false;
            }

            const stationModels = _.uniq(this.workspace.allStations.map((s) => s.model.name));
            const anyNodeRed = stationModels.filter((name) => name.indexOf("NodeRed") >= 0); // TODO This should be a flag.

            console.log("viz:export-disabled", stationModels, anyNodeRed);

            return anyNodeRed.length == 0;
        },
    },
});
</script>

<style lang="scss">
@use "src/scss/layout";
@use "src/scss/mixins";
@use "src/scss/variables";

.vue-treeselect__control {
    @include mixins.bp-down(variables.$sm) {
        height: 29px;
        font-size: 12px;
    }
}

.vue-treeselect__placeholder,
.vue-treeselect__single-value {
    @include mixins.bp-down(variables.$sm) {
        line-height: 29px;
    }
}

#vg-tooltip-element {
    background-color: #f4f5f7;
    border-radius: 1px;
    box-shadow: none;
    border: none;
    text-align: left;
    font-family: "Avenir", sans-serif;
    color: #2c3e50;

    h3 {
        margin-top: 0;
        margin-bottom: 0;
        margin-right: 5px;
        font-size: 13px;
        display: flex;
        align-items: center;
        line-height: 24px;
    }
    .tooltip-color {
        margin-right: 5px;
        font-size: 2em;
    }
    p {
        margin: 0.3em;
    }
    p.value {
        font-size: 16px;
    }
    p.time {
        font-size: 13px;
    }
}
#vg-tooltip-element .key {
    display: none;
}
#vg-tooltip-element table tr:first-of-type td.value {
    text-align: center;
    font-family: "Avenir", sans-serif;
    font-size: 16px;
    color: #2c3e50;
}
#vg-tooltip-element table tr:nth-of-type(2) td.value {
    text-align: center;
    font-family: "Avenir", sans-serif;
    font-size: 13px;
    color: #2c3e50;
}

.explore-view {
    text-align: left;
    background-color: #fcfcfc;
    padding: 40px;
    flex-grow: 1;

    @include mixins.bp-down(variables.$lg) {
        padding: 30px 45px 60px;
    }

    @include mixins.bp-down(variables.$sm) {
        padding: 30px 20px 30px;
    }

    @include mixins.bp-down(variables.$sm) {
        padding: 20px 10px 10px;
    }
}
.explore-header {
    margin-bottom: 1em;
    position: relative;
}
.explore-header .button {
    margin-left: 20px;
    font-size: 12px;
    padding: 5px 10px;
    background-color: #ffffff;
    border: 1px solid rgb(215, 220, 225);
    border-radius: 4px;
    cursor: pointer;
}

.explore-links {
    @include mixins.position(absolute, 0 0 null null);

    .link {
        color: variables.$color-primary;
        font-size: 12px;
        letter-spacing: 0.07px;
        text-decoration: initial;
        display: block;

        body.floodnet & {
            color: variables.$color-dark;
        }
    }
}

.workspace-container {
    display: flex;
    flex-direction: column;
    border-radius: 1px;
    box-shadow: 0 0 4px 0 rgba(0, 0, 0, 0.07);
    border: solid 1px #f4f5f7;
    min-height: 70vh;

    @include mixins.bp-down(variables.$sm) {
        border: 0;
        box-shadow: unset;
    }
}
.tree-container {
    flex: 0;
}
.loading-scrubber {
    padding: 20px;
}
.groups-container {
    background-color: white;
}

.icons-container {
    margin-top: 30px;
    display: flex;
    justify-content: center;
    align-items: center;
    flex-direction: row;
    padding-left: 20px;
    padding-right: 20px;
}

.icons-container.linked {
    background-color: #efefef;
    height: 1px;
}

.icons-container.unlinked {
    border-top: 1px solid #efefef;
    border-bottom: 1px solid #efefef;
    background-color: #fcfcfc;
    height: 8px;
}

.icons-container div:first-child {
    margin-right: auto;
    visibility: hidden;
}
.icons-container div:last-child {
    margin-left: auto;
}
.icons-container .icon {
    background-color: #fcfcfc;
    box-shadow: inset 0 1px 3px 0 rgba(0, 0, 0, 0.11);
    border: 1px solid var(--color-border);
    border-radius: 50%;
    cursor: pointer;
    font-size: 28px;
    padding: 5px;

    &:before {
        color: var(--color-dark);
    }
}

.icons-container .remove-icon {
    background-position: center;
    background-image: url(../../assets/Icon_Close_Circle.png);
    background-size: 20px;
    background-repeat: no-repeat;
    width: 20px;
    height: 20px;
}

.vega-embed {
    width: 100%;

    summary {
        z-index: 0 !important;
        margin-left: 0.25em;
        margin-right: 0.5em;
    }

    details {
        @include mixins.bp-down(variables.$sm) {
            bottom: -360px;
            position: absolute;
            left: 50%;
        }
    }
}
.graph .vega-embed:not(.vega-embed--dummy) {
    height: 340px;
}
.graph .vega-embed--dummy {
    overflow: visible;
    z-index: variables.$z-index-top;
}
.scrubber .vega-embed {
    height: 40px;

    summary {
        display: none;
    }
}

.workspace-container {
    position: relative;

    .busy-panel {
        position: absolute;
        width: 100%;
        height: 100%;
        display: none;
        z-index: 5;
        opacity: 0.5;
        align-items: center;
        justify-content: center;
    }

    &.busy .busy-panel {
        display: flex;
        background-color: #e2e4e6;

        .spinner {
            width: 60px;
            height: 60px;

            div {
                width: 60px;
                height: 60px;
                border-width: 6px;
            }
        }
    }

    .viz-loading {
        height: 300px;
        display: flex;
        align-items: center;
    }
}

.controls-container {
    margin-left: 40px;
    margin-right: 40px;
    margin-bottom: 10px;

    @include mixins.bp-down(variables.$sm) {
        margin: 0 0 28px;
    }
}

.controls-container .row {
    display: flex;
}

.controls-container .row-1 {
    padding: 10px;
    border-bottom: 1px solid #efefef;
    margin-bottom: 5px;
    align-items: center;
    min-height: 60px;

    @include mixins.bp-down(variables.$md) {
        min-height: unset;
        padding: 0;
        border: 0;
    }
}

.controls-container .row-2 {
    margin-top: 5px;
    padding: 10px;
}

.controls-container .left {
    display: flex;
    align-items: center;
    flex-direction: column;
}

.controls-container .left .row {
    align-items: center;
    display: flex;

    @include mixins.bp-down(variables.$sm) {
        align-items: flex-start;
    }

    &:not(:first-of-type) {
        margin-top: 10px;
    }

    .actions {
        margin-left: 1em;
        display: flex;
        align-items: center;

        @include mixins.bp-down(variables.$sm) {
            display: none;
        }

        .button {
            margin-bottom: 0;
        }
    }
}

.controls-container .tree-pair {
    display: flex;
    align-items: center;
    width: 100%;
    flex: 0 0 500px;

    @include mixins.bp-down(variables.$sm) {
        flex: 1 1 auto;
        flex-wrap: wrap;
    }
}

.controls-container .tree-pair > div {
    flex: 0 1 auto;

    &:first-of-type {
        @include mixins.bp-down(variables.$sm) {
            margin-bottom: 12px;
        }
    }
}

.tree-key {
    flex-basis: 0;
    margin-right: 15px;
    line-height: 35px;
    font-size: 40px;

    @include mixins.bp-down(variables.$sm) {
        line-height: 27px;
        margin-right: 7px;
    }

    body.floodnet & {
        margin-top: -10px;
    }
}

.group-no-data .controls-container .right {
    opacity: 0.4;
    pointer-events: none;
}

.controls-container .right {
    display: flex;
    flex-wrap: wrap;
    justify-content: flex-end;
    align-items: center;

    @include mixins.bp-down(variables.$md) {
        position: absolute;
        bottom: 35px;
        max-width: 400px;
        left: 50%;
        transform: translateX(-50%);
        width: 100%;
    }

    &.time {
        margin-left: auto;
    }
}

.controls-container .right {
    font-size: 12px;
}

.controls-container .right.half {
    align-items: flex-start;
    flex: 0 0 140px;

    @include mixins.bp-down(variables.$md) {
        display: none;
    }
}

.controls-container .view-by {
    margin: 0 10px 0 10px;

    @include mixins.bp-down(variables.$md) {
        display: none;
    }
}

.controls-container .fast-time {
    padding: 4px 10px 3px 10px;
    cursor: pointer;
    color: #6a6d71;

    @include mixins.bp-down(variables.$md) {
        padding: 4px 6px 3px 6px;
        font-size: 11px;
    }
}

.controls-container .fast-time-container {
    display: flex;
    align-items: center;

    @include mixins.bp-down(variables.$md) {
        flex: 100%;
        justify-content: space-between;
        margin-bottom: 15px;
    }
}

.controls-container .date-picker {
    margin-left: 20px;
    gap: 8px;

    @include mixins.bp-down(variables.$md) {
        width: 100%;
        margin: 0;

        span {
            width: 50%;
        }

        input {
            width: 100%;
        }
    }

    input {
        height: 32px;
        padding: 7px 11px 4px 11px;
        border: 1px solid variables.$color-border;
        border-radius: 2px;
        cursor: pointer;
        font-family: variables.$font-family-medium;
        box-sizing: border-box;

        @include mixins.bp-down(variables.$md) {
            height: 29px;
            color: #000;
            font-size: 12px;
        }
    }

    .vc-day-layer {
        left: -2px;
    }
}

.controls-container .fast-time.selected {
    font-weight: 900;
    color: #fff;
    background: variables.$color-primary;
    border: 1px solid variables.$color-primary;
    border-radius: 2px;

    body.floodnet & {
        background: variables.$color-floodnet-dark;
        border-color: variables.$color-floodnet-dark;
    }
}

.controls-container .left .button {
    margin-right: 20px;
    font-size: 12px;
    padding: 5px 10px;
    background-color: #ffffff;
    border: 1px solid rgb(215, 220, 225);
    border-radius: 4px;
    cursor: pointer;
}

.debug-panel {
    font-size: 8px;
}

.notification {
    margin-top: 20px;
    margin-bottom: 20px;
    padding: 20px;
    background-color: #f8d7da;
    border: 2px;
    border-radius: 4px;
}

.svg-container {
    display: inline-block;
    position: relative;
    width: 100%;
    vertical-align: top;
    overflow: hidden;
}

.svg-content-responsive {
    display: inline-block;
    position: absolute;
    top: 10px;
    left: 0;
}

.viz.map .viz-map {
    height: 400px;
    margin-bottom: 20px;
}

.share-floating,
.exports-floating {
    position: absolute;
    right: 0;
    top: 70px;
    bottom: 0;
    background-color: #fcfcfc;
    border-left: 2px solid var(--color-border);
    z-index: 10;
    overflow-y: scroll;
    width: 30em;

    @include mixins.bp-down(variables.$sm) {
        width: 100%;
        top: 0;
        left: 0;
    }
}

.loading-options {
    text-align: center;
    color: #afafaf;
}

.button.compare {
    display: flex;
    align-items: center;
    user-select: none;

    @include mixins.bp-down(variables.$sm) {
        display: none;
    }

    &.disabled {
        pointer-events: none;
        opacity: 0.6;
        cursor: not-allowed;
    }

    div {
        padding-left: 1em;
    }
}

.brush_brush_bg path {
    body.floodnet & {
        fill: var(--color-primary);
        fill-opacity: 1;
    }
}

.layer_1_marks path {
    fill: var(--color-primary);

    body.floodnet & {
        fill: #3f5d62;
    }
}

.de_flag path {
    fill: #52b5e0;

    body.floodnet & {
        fill: var(--color-dark);
    }
}

.one {
    display: flex;
    flex-direction: row;

    @include mixins.bp-down(variables.$sm) {
        color: #979797;
        font-size: 14px;
        letter-spacing: 0.06px;
    }
}

.button-submit {
    padding: 0 28px;

    &:nth-child(n + 1) {
        margin-left: 20px;

        @include mixins.bp-down(variables.$sm) {
            margin-left: 5px;
        }
    }

    @include mixins.bp-down(variables.$lg) {
        padding: 0 14px;
        height: 40px;
        font-size: 16px;
    }

    @include mixins.bp-down(variables.$sm) {
        height: 30px;
        width: 30px;
        padding: 0;

        .icon {
            margin: 0;
            font-size: 18px;

            &-export {
                transform: translateX(1px);
            }
        }
    }

    &-text {
        @include mixins.bp-down(variables.$sm) {
            display: none;
        }
    }
}
.station-summary {
    background-color: #fff;
    border-bottom: 1px solid var(--color-border);
    padding: 20px;
    display: flex;
    justify-content: space-between;

    @include mixins.bp-down(variables.$sm) {
        flex-direction: column;
        background: transparent;
        padding: 0 0 10px;

        .pagination {
            margin-top: 0.5em;
        }

        .navigate-button {
            width: 16px;
            height: 16px;
        }
    }

    .summary-content {
        .image-container {
            flex-basis: 90px;
            height: 90px;
            margin-right: 10px;
        }
    }

    .station-details {
        padding: 0;
    }

    .station-modules {
        margin-top: 3px;
    }

    .station-battery-container {
        margin-top: 8px;
    }
}
.pagination {
    display: flex;
    margin-right: 13px;
    justify-content: center;

    @include mixins.bp-down(variables.$sm) {
        margin-left: auto;
        margin-right: 0;
    }
}
</style>

<style scoped lang="scss">
@use "src/scss/mixins";
@use "src/scss/variables";

::v-deep .double-header {
    @include mixins.bp-down(variables.$sm) {
        .actions {
            position: absolute;
            right: 0;
            margin: 0 !important;
        }
        .one {
            font-size: 14px;
            display: flex;
            align-items: center;
        }

        .back {
            margin-bottom: 25px;
        }
    }
}

::v-deep .scrubber {
    @include mixins.bp-down(variables.$md) {
        padding-bottom: 120px;
    }
}

::v-deep .groups-container {
    position: relative;
}

::v-deep .time-series-graph {
    position: relative;

    .info {
        z-index: variables.$z-index-top;
        position: absolute;
        top: 17px;
        left: 20px;
    }
}

::v-deep .group-no-data {
    .viz,
    .scrubber {
        opacity: 0.4;
        pointer-events: none;
    }
}

::v-deep .group-no-data-msg {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    font-size: 24px;
    z-index: variables.$z-index-top;
    background: #ffff;
    padding: 10px;
    box-shadow: 0 2px 4px 0 rgba(0, 0, 0, 0.07);
    white-space: nowrap;
}

::v-deep .chart-type.disabled {
    opacity: 0.5;
    pointer-events: none;
}
</style>
