<template>
    <div class="project-thumbnails">
        <ProjectThumbnail v-for="project in projects" v-bind:key="project.id" :project="project" :invited="invited" />
    </div>
</template>

<script lang="ts">
import ProjectThumbnail from "./ProjectThumbnail.vue";

export default {
    name: "ProjectThumbnails",
    components: {
        ProjectThumbnail,
    },
    props: {
        projects: {
            type: Array,
            required: true,
        },
        invited: {
            type: Boolean,
            default: false,
        },
    },
};
</script>

<style scoped lang="scss">
@use "src/scss/mixins";
@use "src/scss/variables";

.project-thumbnails {
    display: flex;
    flex-wrap: wrap;
    text-align: left;
    margin: 0 -12px;

    @include mixins.bp-down(variables.$xs) {
        margin: 0;
    }

    * {
        box-sizing: border-box;
    }
}
</style>
