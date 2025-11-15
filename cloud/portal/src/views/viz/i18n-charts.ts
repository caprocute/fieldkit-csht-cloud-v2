import i18n from "@/i18n";

export default {
    timeSeriesXAxisLabel() {
        return i18n.t("dataView.timeSeriesXAxisLabel", { timeZone: Intl.DateTimeFormat().resolvedOptions().timeZone });
    },
};
