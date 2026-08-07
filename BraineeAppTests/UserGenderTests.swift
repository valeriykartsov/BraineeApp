//
//  UserGenderTests.swift
//  BraineeAppTests
//
//  Пол пользователя: resolve, русские названия, round-trip rawValue.

import Testing
@testable import BraineeApp

struct UserGenderTests {
    // Неизвестное или пустое значение из JSON → «Не указан».
    @Test func неизвестныйИлиNilRaw_resolveВозвращаетUnspecified() {
        #expect(UserGender.resolved(from: nil) == .unspecified)
        #expect(UserGender.resolved(from: "unknown") == .unspecified)
        #expect(UserGender.resolved(from: "") == .unspecified)
    }

    // Известные raw value читаются корректно.
    @Test func известныйRaw_resolveВозвращаетСоответствующийКейс() {
        #expect(UserGender.resolved(from: "male") == .male)
        #expect(UserGender.resolved(from: "female") == .female)
        #expect(UserGender.resolved(from: "other") == .other)
        #expect(UserGender.resolved(from: "unspecified") == .unspecified)
    }

    // Подписи в UI на русском и не пустые.
    @Test func всеКейсы_имеютРусскиеНепустыеTitle() {
        #expect(UserGender.unspecified.title == "Не указан")
        #expect(UserGender.male.title == "Мужской")
        #expect(UserGender.female.title == "Женский")
        #expect(UserGender.other.title == "Другой")

        for gender in UserGender.allCases {
            #expect(!gender.title.isEmpty)
            #expect(UserGender(rawValue: gender.rawValue) == gender)
        }
    }
}
