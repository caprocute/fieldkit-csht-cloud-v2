/// <reference types="cypress" />
// ***********************************************
// This example commands.ts shows you how to
// create various custom commands and overwrite
// existing commands.
//
// For more comprehensive examples of custom
// commands please read more here:
// https://on.cypress.io/custom-commands
// ***********************************************
//
//
// -- This is a parent command --
// Cypress.Commands.add('login', (email, password) => { ... })
//
//
// -- This is a child command --
// Cypress.Commands.add('drag', { prevSubject: 'element'}, (subject, options) => { ... })
//
//
// -- This is a dual command --
// Cypress.Commands.add('dismiss', { prevSubject: 'optional'}, (subject, options) => { ... })
//
//
// -- This will overwrite an existing command --
// Cypress.Commands.overwrite('visit', (originalFn, url, options) => { ... })
//
// declare global {
//   namespace Cypress {
//     interface Chainable {
//       login(email: string, password: string): Chainable<void>
//       drag(subject: string, options?: Partial<TypeOptions>): Chainable<Element>
//       dismiss(subject: string, options?: Partial<TypeOptions>): Chainable<Element>
//       visit(originalFn: CommandOriginalFn, url: string, options: Partial<VisitOptions>): Chainable<Element>
//     }
//   }
// }
//import {Services} from "../../src/api";

export const apiUrl = "http://127.0.0.1:8080/";

Cypress.Commands.add("login", () => {
    const existingToken = window.localStorage["fktoken"];

    cy.log("login");

    if (!existingToken) {
        cy.request({
            method: "POST",
            url: apiUrl + "login",
            body: {
                email: "test@conservify.org",
                password: "asdfasdfasdf",
            },
        }).then((response) => {
            const token = response.headers.authorization;
            if (typeof token === "string") {
                console.log("saved new token", token);
                const sanitized = token.replace("Bearer ", "");
                window.localStorage["fktoken"] = JSON.stringify(sanitized);
            }
        });
    }
});

Cypress.Commands.add("addStation", () => {
    const headers = {
        "Content-Type": "application/json",
    };
    const token = "Bearer " + JSON.parse(window.localStorage["fktoken"]);
    headers["Authorization"] = token;

    cy.request({
        method: "POST",
        headers,
        url: apiUrl + "stations",
        body: {
            name: "Test Station",
            deviceId: "706C616365686F6C646572",
        },
    }).then((response) => {
        cy.log(response.body);
        cy.wrap(response.body.id).as("stationId");
        cy.wrap("/station/" + response.body.id).as("stationPageUrl");
    });
});
