package com.example.commande;

import com.example.Article;
import com.fasterxml.jackson.annotation.JsonIgnore;
import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.Entity;
import jakarta.persistence.ManyToOne;

/**
 * Une ligne de commande = un article + une quantité (+ son prix figé).
 *
 * C'est le côté PROPRIÉTAIRE de la relation avec Commande : c'est cette table
 * qui porte la clé étrangère commande_id (via @ManyToOne ci-dessous).
 */
@Entity
public class LigneCommande extends PanacheEntity {

    /**
     * La commande "parente".
     * @ManyToOne : plusieurs lignes -> une même commande.
     * @JsonIgnore : coupe la récursion JSON (Commande -> lignes -> commande -> ...).
     *   Quand on sérialise une Commande, ses lignes ne ré-affichent pas la commande.
     */
    @ManyToOne(optional = false)
    @JsonIgnore
    public Commande commande;

    /** L'article commandé. */
    @ManyToOne(optional = false)
    public Article article;

    /** Quantité commandée (toujours positive). */
    public int quantite;

    /**
     * Prix unitaire FIGÉ au moment de la commande.
     * On le copie depuis l'article à la création : si le prix de l'article change
     * plus tard, la commande garde le prix d'origine (bonne pratique GPAO).
     */
    public double prixUnitaire;
}
