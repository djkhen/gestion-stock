package com.example.mouvement;

import com.example.Article;
import jakarta.enterprise.context.ApplicationScoped;
import jakarta.ws.rs.WebApplicationException;

/**
 * Logique métier des mouvements de stock, CENTRALISÉE ici.
 *
 * Avant, cette règle vivait dans MouvementResource.creer(). On l'extrait pour
 * pouvoir la RÉUTILISER (POST /mouvements ET validation d'une commande) sans
 * la dupliquer : « une règle métier = un seul endroit ».
 *
 * @ApplicationScoped : un seul exemplaire (singleton CDI) injectable partout.
 *
 * NB : les méthodes ne sont PAS @Transactional — c'est l'APPELANT (la Resource)
 * qui ouvre la transaction. Ainsi, valider une commande applique TOUTES ses
 * lignes dans UNE SEULE transaction (rollback global si une ligne échoue).
 */
@ApplicationScoped
public class MouvementService {

    /**
     * Applique un mouvement à un article : ajuste le stock, crée et persiste
     * le Mouvement correspondant, puis le renvoie.
     */
    public Mouvement appliquer(Article article, TypeMouvement type, int quantite, String motif) {
        if (type != TypeMouvement.AJUSTEMENT && quantite <= 0) {
            throw new WebApplicationException("La quantité doit être positive", 400);
        }

        switch (type) {
            case ENTREE -> article.quantiteStock += quantite;
            case SORTIE -> {
                if (article.quantiteStock < quantite) {
                    throw new WebApplicationException(
                            "Stock insuffisant pour « " + article.designation + " »", 409);
                }
                article.quantiteStock -= quantite;
            }
            case AJUSTEMENT -> {
                if (quantite < 0) {
                    throw new WebApplicationException(
                            "Ajustement : la quantité doit être positive ou nulle", 409);
                }
                article.quantiteStock = quantite;
            }
            case TRANSFERT -> throw new WebApplicationException(
                    "Transfert : nécessite les emplacements (à venir)", 501);
        }

        Mouvement mouvement = new Mouvement();
        mouvement.article = article;
        mouvement.type = type;
        mouvement.quantite = quantite;
        mouvement.motif = motif;
        mouvement.persist();
        return mouvement;
    }
}
