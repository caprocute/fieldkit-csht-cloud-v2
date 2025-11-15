<!-- TODO: confirm if it can be deleted -->
<template>
    <StandardLayout>
        <div class="container-wrap notes-view">
            <DoubleHeader
                v-if="project"
                :title="project.name"
                :subtitle="$tc('fieldNotes.title')"
                :backTitle="$tc('layout.backProjectDashboard')"
                backRoute="v iewProject"
                :backRouteParams="{ id: projectId }"
            />
            <DoubleHeader title="My Stations" subtitle="Field Notes" backTitle="Back to Dashboard" backRoute="projects" v-if="!project" />

            <div class="lower">
                <div class="loading-container empty" v-if="!hasStations">There are no stations to view.</div>
                <template v-else>
                    <template v-if="isMobileView()">
                        <div class="station-tabs">
                            <div
                                class="tab"
                                v-for="station in stations"
                                v-bind:key="station.id"
                                v-bind:class="{ active: isStationSelected && selectedStation.id === station.id }"
                            >
                                <div class="tab-wrap" v-on:click="onSelected(station)">
                                    <div class="name">{{ station.name }}</div>
                                    <div v-if="station.deployedAt" class="deployed">Deployed</div>
                                    <div v-else class="undeployed">Not Deployed</div>
                                </div>
                                <div class="tab-content" v-if="selectedStation && selectedNotes">
                                    <div v-if="loading" class="loading-container">
                                        <Spinner />
                                    </div>
                                    <div class="notifications">
                                        <div v-if="failed" class="notification failed">Oops, there was a problem.</div>

                                        <div v-if="success" class="notification success">Saved.</div>
                                    </div>
                                    <NotesForm
                                        v-bind:key="stationId"
                                        :station="selectedStation"
                                        :notes="selectedNotes"
                                        :readonly="project.project.readOnly"
                                        @save="saveForm"
                                    />
                                </div>
                                <div v-else class="tab-content empty">Please choose a station from the left.</div>
                            </div>
                        </div>
                    </template>
                    <template v-else>
                        <div class="station-tabs">
                            <div
                                class="tab"
                                v-for="station in stations"
                                v-bind:key="station.id"
                                v-bind:class="{ active: selectedStation.id === station.id }"
                                v-on:click="onSelected(station)"
                            >
                                <div class="tab-wrap">
                                    <div class="name">{{ station.name }}</div>
                                    <div v-if="station.deployedAt" class="deployed">Deployed</div>
                                    <div v-else class="undeployed">Not Deployed</div>
                                </div>
                            </div>
                        </div>
                        <div class="tab-content" v-if="selectedStation && selectedNotes">
                            <div v-if="loading" class="loading-container">
                                <Spinner />
                            </div>
                            <div class="notifications">
                                <div v-if="failed" class="notification failed">Oops, there was a problem.</div>

                                <div v-if="success" class="notification success">Saved.</div>
                            </div>
                            <NotesForm
                                v-bind:key="stationId"
                                :station="selectedStation"
                                :notes="selectedNotes"
                                :readonly="project.project.readOnly"
                                @save="saveForm"
                                @change="onChange"
                            />
                        </div>
                        <div v-else class="tab-content empty">Please choose a station from the left.</div>
                    </template>
                </template>
            </div>
        </div>
    </StandardLayout>
</template>

<script lang="ts">
import _ from "lodash";
import Vue from "vue";
import Promise from "bluebird";
import CommonComponents from "@/views/shared";
import StandardLayout from "../StandardLayout.vue";
import NotesForm from "./NotesForm.vue";

import { mapState, mapGetters } from "vuex";
import * as ActionTypes from "@/store/actions";
import { GlobalState } from "@/store/modules/global";

import { serializePromiseChain } from "@/utilities";

import { PortalStationNotesReply, Notes, mergeNotes } from "./model";
import { DisplayStation, DisplayProject } from "@/store";
import { confirmLeaveWithDirtyCheck } from "@/store/modules/dirty";

export default Vue.extend({
    name: "NotesView",
    components: {
        ...CommonComponents,
        StandardLayout,
        NotesForm,
    },
    props: {
        projectId: {
            type: Number,
            required: false,
        },
        stationId: {
            type: Number,
            required: false,
        },
        selected: {
            type: Object,
            required: false,
        },
    },
    data(): {
        notes: { [stationId: number]: PortalStationNotesReply };
        loading: boolean;
        success: boolean;
        failed: boolean;
        mobileView: boolean;
        isStationSelected: boolean;
    } {
        return {
            notes: {},
            loading: false,
            success: false,
            failed: false,
            mobileView: window.screen.availWidth < 1040,
            isStationSelected: true,
        };
    },
    computed: {
        ...mapGetters({ isAuthenticated: "isAuthenticated", isBusy: "isBusy" }),
        ...mapState({
            user: (s: GlobalState) => s.user.user,
            userProjects: (s: GlobalState) => s.stations.user.projects,
        }),
        hasStations(): boolean {
            return this.visibleStations.length > 0;
        },
        project(): DisplayProject | null {
            if (this.projectId) {
                return this.$getters.projectsById[this.projectId];
            }
            return null;
        },
        stations(): DisplayStation[] {
            return this.$getters.projectsById[this.projectId].stations;
        },
        visibleStations(): DisplayStation[] {
            if (this.projectId) {
                const project = this.$getters.projectsById[this.projectId];
                if (project) {
                    return project.stations;
                }
                return [];
            }
            return this.$store.state.stations.user.stations;
        },
        selectedStation(): DisplayStation | null {
            if (this.stationId) {
                const station = this.$getters.stationsById[this.stationId];
                if (station) {
                    return station;
                }
            }
            return null;
        },
        selectedNotes(): PortalStationNotesReply | null {
            if (this.stationId && this.notes) {
                return this.notes[this.stationId];
            }
            return null;
        },
    },
    watch: {
        async stationId(): Promise<void> {
            await this.loadNotes(this.stationId);
        },
    },
    async mounted(): Promise<void> {
        const desktopBreakpoint = 768;
        const windowAny: any = window;
        const resizeObserver = new windowAny.ResizeObserver((entries) => {
            const windowWidth = entries[0].contentRect.width;

            if (this.$data.mobileView && windowWidth > desktopBreakpoint) {
                this.$data.mobileView = false;
            }
            if (!this.$data.mobileView && windowWidth < desktopBreakpoint) {
                this.$data.mobileView = true;
            }
        });
        resizeObserver.observe(document.querySelector("body"));

        const pending: Promise<never>[] = [];
        if (this.projectId) {
            pending.push(this.$store.dispatch(ActionTypes.NEED_PROJECT, { id: this.projectId }));
        }
        if (this.stationId) {
            pending.push(this.loadNotes(this.stationId));
        }
        await Promise.all(pending);
    },
    beforeRouteLeave(to: any, from: any, next: any) {
        confirmLeaveWithDirtyCheck(() => {
            next();
        }, this);
    },
    methods: {
        async loadNotes(stationId: number): Promise<void> {
            this.success = false;
            this.failed = false;
            this.loading = true;
            await this.$services.api.getStationNotes(stationId).then((notes) => {
                Vue.set(this.notes, stationId, notes);
                this.loading = false;
            });
        },
        async onSelected(station): Promise<void> {
            if (this.stationId != station.id) {
                await this.$router.push({
                    name: this.projectId ? "viewProjectStationNotes" : "viewStationNotes",
                    params: {
                        projectId: this.projectId.toString(),
                        stationId: station.id,
                    },
                });
                this.isStationSelected = true;
                return;
            }
            // allows collapsing of selected station tab on mobile
            if (this.isMobileView()) {
                this.isStationSelected = !this.isStationSelected;
            }
        },
        async saveForm(formNotes: Notes): Promise<void> {
            this.success = false;
            this.failed = false;

            await serializePromiseChain(formNotes.addedPhotos, (photo) => {
                return this.$services.api.uploadStationMedia(this.stationId, photo.key, photo.file).then((media) => {
                    console.log(media);
                    return [];
                });
            }).then(() => {
                const payload = mergeNotes(this.notes[this.stationId], formNotes);
                return this.$services.api.patchStationNotes(this.stationId, payload).then(
                    (updated) => {
                        this.success = true;
                        console.log("success", updated);
                    },
                    () => {
                        this.failed = true;
                        console.log("failed");
                    }
                );
            });
        },
        isMobileView(): boolean {
            return this.$data.mobileView;
        },
    },
});
</script>

<style scoped lang="scss">
@use "src/scss/layout";
@use "src/scss/mixins";
@use "src/scss/variables";

.notes-view {
    @include mixins.bp-down(variables.$md) {
        max-width: 600px;
    }
    @include mixins.bp-down(variables.$xs) {
        padding-bottom: 100px;
    }
}
.notes-view .lower {
    display: flex;
    background: white;
    margin-top: 20px;
    position: relative;

    @include mixins.bp-down(variables.$xs) {
        margin-top: -15px;
    }
}
.loading-container {
    height: 100%;
    @include mixins.flex(center);
}
.notes-view .lower .loading-container.empty {
    padding: 20px;
}

.notification.success {
    margin-top: 20px;
    margin-bottom: 20px;
    padding: 20px;
    border: 2px;
    border-radius: 4px;
}
.notification.success {
    background-color: #d4edda;
}
.notification.failed {
    background-color: #f8d7da;
}
.notifications {
    padding: 0 10px;
}

.spinner {
    margin-top: 40px;
    margin-left: auto;
    margin-right: auto;
}

.station-tabs {
    text-align: left;
    display: flex;
    flex-direction: column;
    flex-basis: 250px;
    flex-shrink: 0;
    border-top: 1px solid var(--color-border);
    border-left: 1px solid var(--color-border);
    border-bottom: 1px solid var(--color-border);

    @include mixins.bp-down(variables.$md) {
        flex-basis: 100%;
    }
}
.tab {
    border-bottom: 1px solid var(--color-border);
    cursor: pointer;

    @include mixins.bp-down(variables.$md) {
        border-right: 1px solid var(--color-border);
        border-bottom: 0;
    }

    &.active {
        border-left: 4px solid var(--color-primary);

        @include mixins.bp-down(variables.$md) {
            border-left: 0;
        }
    }

    &-wrap {
        position: relative;
        padding: 16px 13px;
        z-index: 10;

        @include mixins.bp-down(variables.$md) {
            padding: 16px 10px;
            border-right: 0;
            transition: max-height 0.33s;

            &:after {
                background: url("../../assets/icon-chevron-right.svg") no-repeat center center;
                transform: rotate(90deg) translateX(-50%);
                content: "";
                width: 20px;
                height: 20px;
                transition: all 0.33s;
                @include mixins.position(absolute, 50% 20px null null);

                .tab.active & {
                    transform: rotate(270deg) translateX(50%);
                }
            }
        }

        .tab.active &:before {
            @include mixins.bp-up(variables.$md) {
                content: "";
                width: 3px;
                height: 100%;
                background: #fff;
                z-index: variables.$z-index-top;
                @include mixins.position(absolute, 0 -2px null null);
            }
        }
    }

    &-content {
        width: calc(100% - 250px);
        z-index: variables.$z-index-top;
        border: 1px solid var(--color-border);

        @include mixins.bp-down(variables.$md) {
            padding-top: 1px;
            width: 100%;
            max-height: 0;
            border: 0;
            border-top: 1px solid var(--color-border);
            overflow: hidden;

            @at-root .tab.active & {
                max-height: unset;
            }
        }
    }
}

.vertical {
    margin-top: auto;
    border-right: 1px solid var(--color-border);
    height: 100%;
}
.name {
    font-size: 16px;
    font-weight: 500;
    color: #2c3e50;
    margin-bottom: 1px;
}
.undeployed {
    @include mixins.bp-down(variables.$md) {
        padding: 0 10px 0 14px;
        width: calc(100% + 24px);
        box-sizing: border-box;
        margin-left: -14px;
    }
}
.undeployed,
.deployed {
    font-size: 13px;
    color: #6a6d71;
    font-weight: 500;
}

::v-deep textarea {
    overflow-y: hidden;
    resize: none;
    color: #2c3e50;
    font-size: 14px !important;

    @include mixins.bp-down(variables.$xs) {
        font-size: 12px !important;
    }
}
</style>
