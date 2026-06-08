package com.example;

import jakarta.persistence.Entity;
import jakarta.persistence.Column;
import io.quarkus.hibernate.orm.panache.PanacheEntity;

/**
 * Entité Article — le catalogue de stock (cœur du MVP "gestion de stocks").
 *
 * Même pattern que Produit : "Active Record" de Panache. L'entité hérite de
 * PanacheEntity (champ "id" auto-généré) et expose des méthodes statiques
 * (listAll, findById, persist...). Les champs publics génèrent
 * automatiquement getters/setters.
 *
 * Les champs sont pensés pour les fonctionnalités suivantes du MVP :
 *  - quantiteStock : alimenté par les entrées/sorties (branche stock-movements)
 *  - seuilAlerte   : déclenche les alertes de rupture (branche dashboard-alerts)
 *  - prixUnitaire  : sert à la valorisation du stock (jalon 2)
 */
@Entity
public class Article extends PanacheEntity {

    /** Référence / code article (SKU). Unique dans le catalogue. */
    @Column(nullable = false, unique = true)
    public String reference;

    /** Libellé court de l'article (ex : "Vis inox M6 x 20"). */
    @Column(nullable = false)
    public String designation;

    @Column(length = 1000)
    public String description;

    /** Unité de gestion : piece, kg, litre, metre... */
    @Column(nullable = false)
    public String unite = "piece";

    /** Quantité actuellement en stock. Jamais négative. */
    @Column(nullable = false)
    public int quantiteStock = 0;

    /** Seuil sous lequel l'article est considéré en rupture / à réapprovisionner. */
    @Column(nullable = false)
    public int seuilAlerte = 0;

    /** Prix unitaire (pour la valorisation du stock). */
    @Column(nullable = false)
    public double prixUnitaire = 0.0;

    /** Vrai si le stock est au niveau d'alerte ou en dessous. */
    public boolean isEnAlerte() {
        return quantiteStock <= seuilAlerte;
    }
}
