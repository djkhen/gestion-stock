package com.example.commande;

import com.example.Article;
import com.example.mouvement.MouvementService;
import com.example.mouvement.TypeMouvement;
import io.quarkus.panache.common.Sort;
import jakarta.inject.Inject;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;

import java.time.LocalDateTime;
import java.util.List;

@Path("/commandes")
@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
public class CommandeResource {

    @Inject
    MouvementService mouvementService;   // réutilise la logique stock existante

    // GET /commandes -> toutes les commandes, plus récentes d'abord.
    @GET
    public List<Commande> liste() {
        return Commande.listAll(Sort.by("dateCreation").descending());
    }

    // GET /commandes/{id} -> une commande (avec ses lignes imbriquées).
    @GET
    @Path("/{id}")
    public Commande parId(@PathParam("id") long id) {
        Commande commande = Commande.findById(id);
        if (commande == null) {
            throw new WebApplicationException("Commande " + id + " introuvable", 404);
        }
        return commande;
    }

    /**
     * POST /commandes -> crée une commande au statut BROUILLON.
     * Corps JSON : { "sens":"ACHAT", "tiers":"Fournisseur X", "reference":"CMD-001",
     *                "lignes":[ { "article":{"id":1}, "quantite":10 } ] }
     *
     * Pour chaque ligne : on RECHARGE l'article côté serveur (entité gérée) et on
     * FIGE son prix dans la ligne. Le stock n'est PAS touché ici (commande = brouillon).
     */
    @POST
    @Transactional
    public Response creer(Commande commande) {
        if (commande.sens == null) {
            throw new WebApplicationException("Le sens (ACHAT/VENTE) est obligatoire", 400);
        }
        if (commande.lignes == null || commande.lignes.isEmpty()) {
            throw new WebApplicationException("Une commande doit avoir au moins une ligne", 400);
        }

        // On force l'état initial (le client ne décide ni du statut ni des dates).
        commande.statut = StatutCommande.BROUILLON;
        commande.dateValidation = null;

        for (LigneCommande ligne : commande.lignes) {
            if (ligne.article == null || ligne.article.id == null) {
                throw new WebApplicationException("Chaque ligne doit référencer un article", 400);
            }
            if (ligne.quantite <= 0) {
                throw new WebApplicationException("La quantité d'une ligne doit être positive", 400);
            }
            Article article = Article.findById(ligne.article.id);
            if (article == null) {
                throw new WebApplicationException("Article " + ligne.article.id + " introuvable", 404);
            }
            ligne.article = article;                    // entité gérée par Hibernate
            ligne.prixUnitaire = article.prixUnitaire;  // FIGE le prix du moment
            ligne.commande = commande;                  // lien retour -> remplit la FK
        }

        commande.persist();   // cascade = ALL -> persiste aussi les lignes
        return Response.status(Response.Status.CREATED).entity(commande).build();
    }

    /**
     * PUT /commandes/{id}/valider -> passe BROUILLON à VALIDEE et GÉNÈRE les mouvements.
     *   ACHAT -> ENTREE (stock +)   |   VENTE -> SORTIE (stock -)
     *
     * @Transactional : tout se joue dans UNE transaction. Si une ligne échoue
     * (ex. stock insuffisant en VENTE -> 409), TOUTES les modifs précédentes
     * sont annulées (rollback) -> cohérence garantie (atomicité).
     */
    @PUT
    @Path("/{id}/valider")
    @Transactional
    public Commande valider(@PathParam("id") long id) {
        Commande commande = Commande.findById(id);
        if (commande == null) {
            throw new WebApplicationException("Commande " + id + " introuvable", 404);
        }
        if (commande.statut != StatutCommande.BROUILLON) {
            throw new WebApplicationException("Seule une commande BROUILLON peut être validée", 409);
        }

        TypeMouvement type = (commande.sens == SensCommande.ACHAT)
                ? TypeMouvement.ENTREE
                : TypeMouvement.SORTIE;

        String motif = "Commande " +
                (commande.reference != null ? commande.reference : "#" + commande.id);

        for (LigneCommande ligne : commande.lignes) {
            mouvementService.appliquer(ligne.article, type, ligne.quantite, motif);
        }

        commande.statut = StatutCommande.VALIDEE;
        commande.dateValidation = LocalDateTime.now();
        return commande;
    }

    /**
     * PUT /commandes/{id}/annuler -> passe BROUILLON à ANNULEE (sans impact stock).
     */
    @PUT
    @Path("/{id}/annuler")
    @Transactional
    public Commande annuler(@PathParam("id") long id) {
        System.out.println("XX Début de la méthode annuler");

        Commande commande = Commande.findById(id);
        if (commande == null) {
            throw new WebApplicationException("Commande " + id + " introuvable", 404);
        }
        System.out.println("XX commande.id = " + commande.id);
        System.out.println("XX article = " + commande.statut);

       if (commande.statut != StatutCommande.BROUILLON) {
            throw new WebApplicationException("Seule une commande BROUILLON peut être annulée", 409);
        }
        System.out.println("XX PASSE LE  throw  "  );
        return commande;
    }
}
