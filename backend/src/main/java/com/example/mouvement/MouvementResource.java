package com.example.mouvement;

import com.example.Article;
import io.quarkus.panache.common.Page;
import io.quarkus.panache.common.Sort;
import jakarta.transaction.Transactional;
import jakarta.ws.rs.*;
import jakarta.ws.rs.core.MediaType;
import jakarta.ws.rs.core.Response;


import java.util.List;

@Path("/mouvements")

@Consumes(MediaType.APPLICATION_JSON)
@Produces(MediaType.APPLICATION_JSON)
// CLIENT  ──── requête (corps JSON) ────►  @Consumes  (j'ACCEPTE du JSON en entrée)
// CLIENT  ◄──── réponse (JSON) ──────────  @Article   (je RENVOIE du JSON en sortie)

// Consumes = Consomme ce qui entre (corps de requête)    → ce que je REÇOIS
// Produces = Produit/Pousse vers l'extérieur (réponse)   → ce que je RENVOIE


public class MouvementResource {

	// GET /mouvements -> tous les mouvements.
	// En JSON, chaque mouvement contient son produit IMBRIQUÉ (grâce à @ManyToOne).
	@GET
	public List<Mouvement> liste() {
		return Mouvement.listAll();
	}



	// GET /mouvements -> tous les mouvements evec id .
	@GET
	@Path("/article/{articleId}")                 // ← chemin propre, pas de conflit
	public List<Mouvement> listeParArticle(@PathParam("articleId") long articleId ) {
		return Mouvement.list("article.id",  Sort.by("date").descending(),articleId);   // filtre : mouvements de cet article
	}



	/**
	 * POST /mouvements?articleId=1
	 * Corps JSON attendu : { "type": "ENTREE", "quantite": 10, "motif": "réception" }
	 *
	 * On reçoit le produitId en paramètre d'URL , on charge
	 * l'article correspondant, puis on l'AFFECTE au mouvement avant de persister.
	 * C'est CE rattachement (mouvement.article = article) qui crée la relation.
	 */
	@POST
	@Transactional
	public Response creer(@QueryParam("articleId") long articleId , Mouvement mouvement) {
		// 1) Retrouver l'article concerné (le côté "one" articleIdde la relation).
		Article article = Article.findById(articleId);
		if (article == null) {
			throw new WebApplicationException("L'article " + articleId + " introuvable", 404);
		}

		// 2) Lier le mouvement à l'article -> remplit la clé étrangère article_id.
		mouvement.article = article;

		if (mouvement.type != TypeMouvement.AJUSTEMENT && mouvement.quantite <= 0) {
			throw new WebApplicationException("La quantité doit être positive", 400);
		}
		switch (mouvement.type) {
			case ENTREE     -> article.quantiteStock += mouvement.quantite;
			case SORTIE     -> {
				if (article.quantiteStock < mouvement.quantite) {
					throw new WebApplicationException( "Stock insuffisant", 409); //409 Conflict
					}
					article.quantiteStock -= mouvement.quantite;
				}

			case AJUSTEMENT -> {
						if( mouvement.quantite >=0 )
							article.quantiteStock = mouvement.quantite;
						else
							throw new WebApplicationException( "Ajustement :  la quantité doit être positive ou nulle ", 409); //409 Conflict
				}
			case TRANSFERT  -> throw new WebApplicationException(
					"Transfert : nécessite les emplacements (à venir)", 501 ) ; //501 = Not Implemented
		}

		// 3) Enregistrement .
		mouvement.persist();

		// 4) Réponse a la requette
		return Response.status(Response.Status.CREATED).entity(mouvement).build();


	}
}
