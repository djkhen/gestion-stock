package com.example;

import io.quarkus.runtime.StartupEvent;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.enterprise.event.Observes;
import jakarta.transaction.Transactional;
import org.jboss.logging.Logger;

/**
 * Insère quelques articles de démonstration au démarrage, uniquement si la
 * table est vide. Même principe que DataInitializer (produits) : on évite de
 * dupliquer les données à chaque redémarrage et on illustre la persistance.
 *
 * Un des articles ("Joint torique") est volontairement sous son seuil d'alerte
 * pour pouvoir tester les alertes de rupture du tableau de bord.
 */
@ApplicationScoped
public class ArticleDataInitializer {

    private static final Logger LOG = Logger.getLogger(ArticleDataInitializer.class);

    @Transactional
    void onStart(@Observes StartupEvent ev) {
        if (Article.count() == 0) {
            LOG.info("Table articles vide : insertion des articles de démonstration.");
            creer("VIS-M6-20", "Vis inox M6 x 20", "Boîte de 100", "piece", 850, 200, 0.12);
            creer("ROULEMENT-608", "Roulement à billes 608ZZ", "8x22x7 mm", "piece", 120, 50, 1.45);
            creer("JOINT-OR-15", "Joint torique Ø15", "NBR 70 Shore", "piece", 10, 40, 0.08);
            creer("HUILE-HYD-46", "Huile hydraulique ISO 46", "Bidon 20 L", "litre", 300, 60, 3.20);
        } else {
            LOG.infof("Table articles déjà peuplée (%d articles), pas d'insertion.", Article.count());
        }
    }

    private void creer(String reference, String designation, String description,
                       String unite, int quantiteStock, int seuilAlerte, double prixUnitaire) {
        Article a = new Article();
        a.reference = reference;
        a.designation = designation;
        a.description = description;
        a.unite = unite;
        a.quantiteStock = quantiteStock;
        a.seuilAlerte = seuilAlerte;
        a.prixUnitaire = prixUnitaire;
        a.persist();
    }
}
