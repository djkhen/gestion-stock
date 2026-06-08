package com.example;

import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.transaction.Transactional;
import org.jboss.logging.Logger;

/**
 * Insère quelques produits de démonstration au démarrage,
 * uniquement si la table est vide (pour ne pas dupliquer les données
 * à chaque redémarrage et démontrer la persistance réelle en base).
 */
@ApplicationScoped
public class DataInitializer {

    private static final Logger LOG = Logger.getLogger(DataInitializer.class);

    @Transactional
    void onStart(@Observes StartupEvent ev) {
        if (Produit.count() == 0) {
            LOG.info("Base vide : insertion des produits de démonstration.");
            creer("Clavier mécanique", "Clavier rétroéclairé switches rouges", 79.90);
            creer("Souris ergonomique", "Souris sans fil 6 boutons", 39.50);
            creer("Écran 27 pouces", "Moniteur QHD 144 Hz", 299.00);
        } else {
            LOG.infof("Base déjà peuplée (%d produits), pas d'insertion.", Produit.count());
        }
    }

    private void creer(String nom, String description, double prix) {
        Produit p = new Produit();
        p.nom = nom;
        p.description = description;
        p.prix = prix;
        p.persist();
    }
}
