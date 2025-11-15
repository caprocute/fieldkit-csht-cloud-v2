<template>
    <div class="datafiles-container">
        <div class="heading">{{ $t("project.dataFiles") }}</div>
        <div class="message">{{ $t("project.noDataFiles") }}</div>
    </div>
</template>

<script>
import _ from "lodash";

export default {
    name: "ProjectDataFiles",
    data: () => {
        return {};
    },
    props: {
        projectStations: { required: true },
    },
};
</script>

<style scoped lang="scss">
@use "src/scss/mixins";
@use "src/scss/variables";

.datafiles-container {
}
.heading {
    font-size: 20px;
    font-weight: 500;
}
.message {
    margin-top: 10px;
    font-family: variables.$font-family-light;
}
</style>
