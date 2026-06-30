package com.example.commande;

import io.quarkus.hibernate.orm.panache.PanacheEntity;
import jakarta.persistence.*;

import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * En-tête d'une commande (achat ou vente) + ses lignes.
 *
 * Première entité MAÎTRE-DÉTAIL du projet : une Commande possède plusieurs
 * LigneCommande via @OneToMany.
 */
@Entity
@Table(name = "commande")
public class Commande extends PanacheEntity {

    /** Référence lisible, ex. "CMD-2026-001". */
    public String reference;

    /** ACHAT (fournisseur) ou VENTE (client). */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public SensCommande sens;

    /** BROUILLON par défaut à la création. */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false)
    public StatutCommande statut = StatutCommande.BROUILLON;

    /** Nom du fournisseur (ACHAT) ou du client (VENTE). */
    public String tiers;

    @Column(nullable = false)
    public LocalDateTime dateCreation;

    /** Renseignée uniquement quand la commande passe à VALIDEE. */
    public LocalDateTime dateValidation;

    /**
     * Les lignes de la commande.
     * @OneToMany(mappedBy = "commande") : la clé étrangère est portée par
     *   LigneCommande.commande (côté propriétaire) ; ici on est le côté "inverse".
     * cascade = ALL    : persister/supprimer la commande propage à ses lignes.
     * orphanRemoval    : retirer une ligne de cette liste la SUPPRIME en base.
     */
    @OneToMany(mappedBy = "commande", cascade = CascadeType.ALL, orphanRemoval = true)
    public List<LigneCommande> lignes = new ArrayList<>();

    @PrePersist
    public void avantInsertion() {
        if (dateCreation == null) {
            dateCreation = LocalDateTime.now();
        }
    }

    /**
     * Total de la commande = Σ (quantité × prix) de chaque ligne.
     * Nommée getTotal() pour que Jackson l'expose comme champ "total" en JSON.
     */
    public double getTotal() {
        return lignes.stream()
                .mapToDouble(l -> l.quantite * l.prixUnitaire)
                .sum();
    }
}
