package com.example.commande;

/**
 * Cycle de vie d'une commande.
 *   BROUILLON : modifiable, aucun impact sur le stock.
 *   VALIDEE   : verrouillée ; les Mouvements ont été générés (le stock a bougé).
 *   ANNULEE   : abandonnée avant validation.
 *
 * Transitions autorisées :
 *   BROUILLON -> VALIDEE   (valider)
 *   BROUILLON -> ANNULEE   (annuler)
 */
public enum StatutCommande {
    BROUILLON,
    VALIDEE,
    ANNULEE
}
