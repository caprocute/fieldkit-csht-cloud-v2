<template>
    <div class="station-projects" v-if="stationProjects.length > 0">
        <template v-if="stationProjects.length === 1">{{ $tc("station.singleProjectTitle") }}&nbsp;</template>
        <template v-else>{{ $tc("station.multipleProjectsTitle") }} &nbsp;</template>
        <router-link
            v-for="(project, index) in stationProjects"
            v-bind:key="project.id"
            :to="{ name: 'viewProject', params: { id: project.id } }"
            target="_blank"
        >
            {{ project.name }}
            <template v-if="stationProjects.length > 1 && index !== stationProjects.length - 1">,&nbsp;</template>
        </router-link>
    </div>
</template>

<script lang="ts">
import Vue from "vue";
import { ActionTypes, Project } from "@/store";

export default Vue.extend({
    name: "StationProjects",
    components: {},
    props: {
        stationId: {
            type: Number,
            required: true,
        },
    },
    computed: {
        stationProjects(): Project[] {
            return this.$store.getters.stationProjects;
        },
    },
    beforeMount() {
        this.$store.dispatch(ActionTypes.NEED_PROJECTS_FOR_STATION, { id: this.stationId });
    },
    methods: {},
});
</script>

<style scoped lang="scss">
@use "src/scss/variables";
@use "src/scss/mixins";

.station-projects {
    font-size: 16px;
    color: #6a6d71;
    margin: 30px 0;

    @include mixins.bp-down(variables.$xs) {
        margin: 20px 0;
    }
}
</style>
