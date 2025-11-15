/// <reference types="cypress" />
import "cypress/support/commands";

describe("Station Page", () => {
    beforeEach(() => {
        cy.login();
        cy.addStation();
    });

    it("should create a new station and navigate to its page", function () {
        cy.visit(this.stationPageUrl);

        cy.get('[data-cy="fieldNotes"]').should("exist");
        cy.get('[data-cy="saveNotes"]').should("exist");
    });

    it("should display save button if user is authenticated", function () {
        cy.visit(this.stationPageUrl);

        cy.get('[data-cy="fieldNotes"]').should("exist");

        cy.get('[data-cy="saveNotes"]', { timeout: 10000 }).should("exist");
    });

    it("should successfully save the form when valid data is entered", function () {
        cy.visit(this.stationPageUrl);

        cy.get('[data-cy="studyObjectiveBody"]').type("Some text");
        cy.get('[data-cy="sitePurposeBody"]').type("Some text");
        cy.get('[data-cy="siteCriteriaBody"]').type("Some text");
        cy.get('[data-cy="siteDescriptionBody"]').type("Some text");
        cy.get('[data-cy="customKeyBody"]').type("Some text");

        cy.get('[data-cy="editCustomKey"]').click();
        cy.get('[data-cy="customKeyTitle"]').clear().type("Some title");

        cy.intercept("PATCH", `/stations/${this.stationId}/notes`).as("submitForm");

        cy.get('.buttons button[type="submit"]').click();

        cy.wait("@submitForm").its("response.statusCode").should("eq", 200);
    });

    it("go back to stations dashboard", function () {
        cy.visit(this.stationPageUrl);

        cy.get('[data-cy="backBtn"]').should("exist").click();
        cy.url().should("eq", Cypress.config("baseUrl") + `/dashboard/stations/${this.stationId}`);
    });

    it("shows Field Notes Section", function () {
        cy.visit(this.stationPageUrl);

        cy.get('[data-cy="fieldNotes"]').should("exist");
    });
});
