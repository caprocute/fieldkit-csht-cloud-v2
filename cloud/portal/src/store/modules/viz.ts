import * as ActionTypes from "@/store/actions";
import * as MutationTypes from "@/store/mutations";

export class VizState {
    stationsAndSensors: { stationName: string; sensorName: string }[] = [{ stationName: "", sensorName: "" }];
}

const getters = {
    getAllVizStationsAndSensors: (state: VizState) => state.stationsAndSensors,
};

const actions = () => {
    return {
        [ActionTypes.RESET_VIZ_STATION_SENSOR_SELECTION]: async ({ commit, state: _state }: { commit: any; state: VizState }) => {
            commit(MutationTypes.RESET_VIZ_STATION_SENSOR_SELECTION);
        },

        [ActionTypes.UPDATE_VIZ_STATION]: async ({ commit }: { commit: any }, payload: { index: number; stationName: string }) => {
            commit(MutationTypes.UPDATE_VIZ_STATION, payload);
        },

        [ActionTypes.UPDATE_VIZ_SENSOR]: async ({ commit }: { commit: any }, payload: { index: number; sensorName: string }) => {
            commit(MutationTypes.UPDATE_VIZ_SENSOR, payload);
        },
    };
};

const mutations = {
    [MutationTypes.RESET_VIZ_STATION_SENSOR_SELECTION](state: VizState) {
        state.stationsAndSensors = [{ stationName: "", sensorName: "" }];
    },

    [MutationTypes.UPDATE_VIZ_STATION](state: VizState, { index, stationName }: { index: number; stationName: string }) {
        if (index >= state.stationsAndSensors.length) {
            state.stationsAndSensors.push({ stationName: stationName, sensorName: "" });
            return;
        }
        state.stationsAndSensors[index].stationName = stationName;
    },

    [MutationTypes.UPDATE_VIZ_SENSOR](state: VizState, { index, sensorName }: { index: number; sensorName: string }) {
        state.stationsAndSensors[index].sensorName = sensorName;
    },
};

export const viz = () => {
    const state = () => new VizState();

    return {
        namespaced: false,
        state,
        getters,
        actions: actions(),
        mutations,
    };
};
