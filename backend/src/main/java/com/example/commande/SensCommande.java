package com.example.commande;

/**
 * Sens d'une commande.
 *   ACHAT : commande fournisseur  -> à la validation, ENTREE de stock (stock +).
 *   VENTE : commande client       -> à la validation, SORTIE de stock (stock -).
 */
public enum SensCommande {
    ACHAT,
    VENTE
}
