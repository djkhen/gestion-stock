package com.example;

import jakarta.persistence.Entity;
import jakarta.persistence.Column;
import io.quarkus.hibernate.orm.panache.PanacheEntity;

/**
 * Entité Produit.
 *
 * On utilise le pattern "Active Record" de Panache : l'entité hérite de
 * PanacheEntity (qui fournit un champ "id" auto-généré) et expose
 * directement des méthodes statiques comme listAll(), findById(), persist()...
 *
 * Les champs sont publics : Panache génère automatiquement les getters/setters.
 */
@Entity
public class Produit extends PanacheEntity {

    @Column(nullable = false)
    public String nom;

    @Column(length = 1000)
    public String description;

    @Column(nullable = false)
    public double prix;
}
