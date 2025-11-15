import _ from "lodash";
import { DisplayStation } from "./stations";
import { GlobalState, GlobalGetters } from "./global";

import { Services, CurrentUser, Project } from "@/api";

export class LayoutState {
    user: CurrentUser | null;
    users: {
        stations: DisplayStation[];
        projects: Project[];
    } = {
        stations: [],
        projects: [],
    };
    community: {
        projects: Project[];
    } = {
        projects: [],
    };
}

const getters = {
    layout: (_state: LayoutState, _getters: any, _rootState: GlobalState, _rootGetters: GlobalGetters) => {
        return {};
    },
};

const actions = (_services: Services) => {
    return {};
};

const mutations = {};

export const layout = (services: Services) => {
    const state = () => new LayoutState();

    return {
        namespaced: false,
        state,
        getters,
        actions: actions(services),
        mutations,
    };
};
