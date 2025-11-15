import _ from "lodash";
import Config from "@/secrets";
import Vuex from "vuex";
import { clock } from "./modules/clock";
import { user } from "./modules/user";
import { stations } from "./modules/stations";
import { map } from "./modules/map";
import { progress } from "./modules/progress";
import { layout } from "./modules/layout";
import { exporting } from "./modules/exporting";
import { notifications } from "./modules/notifications";
import { dataEvents } from "./modules/discussion";
import { Services } from "@/api";

export * from "@/api";

export * from "./modules/clock";
export * from "./modules/user";
export * from "./modules/stations";
export * from "./modules/exporting";
export * from "./modules/map";
export * from "./modules/progress";
export * from "./modules/layout";
export * from "./modules/notifications";
export * from "./modules/global";
export * from "./modules/notes";
export * from "./modules/fieldNotes";
export * from "./modules/discussion";

import * as MutationTypes from "./mutations";
import * as ActionTypes from "./actions";
import { notes } from "@/store/modules/notes";
import { snackbar } from "@/store/modules/snackbar";
import { fieldNotes } from "@/store/modules/fieldNotes";
import { dirty } from "@/store/modules/dirty";
import { viz } from "@/store/modules/viz";
import { exploreView } from "@/store/modules/exploreView";

export { MutationTypes, ActionTypes };

export * from "./typed-actions";
export * from "./map-types";

export default function (services: Services) {
    return new Vuex.Store({
        plugins: Config.vuexLogging ? [] : [],
        modules: {
            clock: clock(services),
            exporting: exporting(services),
            notifications: notifications(services),
            user: user(services),
            stations: stations(services),
            map: map(services),
            progress: progress(services),
            layout: layout(services),
            notes: notes(services),
            fieldNotes: fieldNotes(services),
            snackbar: snackbar(),
            discussion: dataEvents(services),
            dirty: dirty(),
            viz: viz(),
            exploreView: exploreView(),
        },
        // This was causing a call stack error (_traverse)
        strict: process.env.NODE_ENV !== "production",
    });
}
