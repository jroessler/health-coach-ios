import Foundation
import SwiftData

@Model
final class NutritionEntry {
    var foodName: String
    var startDate: String
    var date: String

    // Macros
    var energyKcal: Double?
    var proteinG: Double?
    var carbsG: Double?
    var fatTotalG: Double?
    var fatSaturatedG: Double?
    var fatPolyunsaturatedG: Double?
    var fatMonounsaturatedG: Double?
    var fiberG: Double?
    var sugarG: Double?

    // Minerals & misc
    var cholesterolMg: Double?
    var sodiumMg: Double?
    var waterMl: Double?

    // Vitamins
    var vitaminAMcg: Double?
    var vitaminCMg: Double?
    var vitaminDMcg: Double?
    var vitaminEMg: Double?
    var vitaminKMcg: Double?
    var vitaminB6Mg: Double?
    var vitaminB12Mcg: Double?
    var thiaminMg: Double?
    var riboflavinMg: Double?
    var niacinMg: Double?
    var folateMcg: Double?
    var pantothenicAcidMg: Double?

    // Minerals
    var ironMg: Double?
    var calciumMg: Double?
    var magnesiumMg: Double?
    var potassiumMg: Double?
    var zincMg: Double?
    var phosphorusMg: Double?
    var manganeseMg: Double?
    var copperMg: Double?
    var seleniumMcg: Double?

    init(foodName: String, startDate: String, date: String) {
        self.foodName = foodName
        self.startDate = startDate
        self.date = date
    }
}
