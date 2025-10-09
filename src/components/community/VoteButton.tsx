"use client";
import { supabase } from "@/lib/supabaseClient";

export default function VoteButton({ postId }:{ postId:string }) {
  return (
    <button className="px-3 py-1 rounded-xl border" onClick={async()=>{
      const { data: me } = await supabase.auth.getUser();
      const voter = me.user?.id;
      if (!voter) return;
      await supabase.from("community_votes").insert({ post_id: postId, voter }).select();
    }}>▲ Upvote</button>
  );
}
